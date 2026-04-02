import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/core/branding/branding_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:infoapp/features/env/pages/show_server_qr_page.dart';
import 'package:infoapp/features/auth/presentation/pages/login_page.dart';
import 'package:infoapp/features/auth/presentation/pages/login_mobile_page.dart';

class SelectServerQrPage extends StatefulWidget {
  const SelectServerQrPage({super.key});

  @override
  State<SelectServerQrPage> createState() => _SelectServerQrPageState();
}

class _SelectServerQrPageState extends State<SelectServerQrPage> {
  bool _processing = false;
  String? _error;
  bool _scannerEnabled = false;
  final MobileScannerController _scannerController =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final TextEditingController _manualUrlController = TextEditingController();
  bool _showManualInput = false;
  static const Color _neutralPurple = Color(0xFF6A1B9A);
  static const Color _neutralPurpleStart = Color(0xFF7B1FA2);
  static const Color _neutralPurpleEnd = Color(0xFF4A148C);

  Future<void> _handlePayload(String raw) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final String? root = _parseRoot(raw);
      if (root == null) {
        setState(() {
          _error = 'QR inválido: no se encontró api_root';
          _processing = false;
        });
        return;
      }
      // Validación básica de URL
      final uri = Uri.tryParse(root);
      if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
        setState(() {
          _error = 'URL inválida en QR';
          _processing = false;
        });
        return;
      }

      await ServerConfig.instance.setCurrentRoot(uri.toString());
      
      // ✅ Recargar branding para el nuevo servidor
      await BrandingService().forceReload();

      if (!mounted) return;
      final bool isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => isMobile ? const LoginMobilePage() : const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _error = 'Error procesando QR: $e';
        _processing = false;
      });
    }
  }

  String? _parseRoot(String raw) {
    final text = raw.trim();
    // 1) JSON con api_root
    if (text.startsWith('{') && text.endsWith('}')) {
      try {
        final map = _tryDecodeJson(text);
        final val = map['api_root'] ?? map['server_root'] ?? map['root'];
        if (val is String) return val;
      } catch (_) {}
    }
    // 2) URL infoapp://env?api_root=...
    if (text.startsWith('infoapp://') || text.startsWith('http')) {
      final uri = Uri.tryParse(text);
      if (uri != null) {
        final qp = uri.queryParameters['api_root'] ?? uri.queryParameters['server_root'];
        if (qp != null && qp.isNotEmpty) return qp;
        // Si es directamente la raíz
        if (uri.hasAuthority && (uri.scheme == 'https' || uri.scheme == 'http')) {
          return uri.removeFragment().toString();
        }
      }
    }
    // 3) Texto plano con URL
    if (text.startsWith('https://') || text.startsWith('http://')) {
      return text;
    }
    return null;
  }

  Map<String, dynamic> _tryDecodeJson(String s) {
    return Map<String, dynamic>.from(
      // ignore: avoid_dynamic_calls
      (const JsonDecoder()).convert(s) as Map,
    );
  }

  Future<void> _saveManualUrl() async {
    final raw = _manualUrlController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Ingresa la URL del servidor');
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http')) || !uri.hasAuthority) {
      setState(() => _error = 'URL inválida. Debe comenzar con http(s)://)');
      return;
    }
    try {
      debugPrint('🔵 Guardando URL del servidor: ${uri.toString()}');
      await ServerConfig.instance.setCurrentRoot(uri.toString());
      
      debugPrint('🔵 URL guardada. Recargando branding...');
      // ✅ Recargar branding para el nuevo servidor
      await BrandingService().forceReload();
      debugPrint('🔵 Branding recargado. Estado: ${BrandingService().isLoaded}');
      debugPrint('🔵 Color primario: ${BrandingService().primaryColor}');
      debugPrint('🔵 Logo URL: ${BrandingService().logoUrl}');
      debugPrint('🔵 Error (si existe): ${BrandingService().lastError}');

      if (!mounted) return;
      final bool isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => isMobile ? const LoginMobilePage() : const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('❌ Error guardando URL: $e');
      setState(() => _error = 'No se pudo guardar la URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar servidor'),
        backgroundColor: _neutralPurple,
        foregroundColor: Colors.white,
      ), 
      body: Container(
        decoration: isMobile
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_neutralPurpleStart, _neutralPurpleEnd],
                ),
              )
            : null,
        child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_scannerEnabled)
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      if (barcodes.isEmpty) return;
                      final value = barcodes.first.rawValue;
                      if (value != null) {
                        _handlePayload(value);
                      }
                    },
                  )
                else
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 10),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner,
                                size: 56, color: _neutralPurple),
                            const SizedBox(height: 12),
                            const Text(
                              'Para acceder al sitio, escanea el QR del servidor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Haz clic en el botón para escanear.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _scannerEnabled = true;
                                  });
                                },
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Escanear QR'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _neutralPurple,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showManualInput = !_showManualInput;
                                  });
                                },
                                icon: const Icon(Icons.link),
                                label: const Text('Configurar URL manualmente'),
                              ),
                            ),
                            if (_showManualInput) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _manualUrlController,
                                decoration: const InputDecoration(
                                  labelText: 'URL del servidor',
                                  hintText: 'https://tu-servidor.com/API_Infoapp',
                                ),
                                keyboardType: TextInputType.url,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _saveManualUrl,
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('Guardar y continuar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _neutralPurple,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_processing)
                  const Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ShowServerQrPage()),
                    );
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Ver QR para compartir servidor'),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              'Escanea el QR provisto para seleccionar el servidor. ',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      ),
    );
  }
  @override
  void dispose() {
    _scannerController.dispose();
    _manualUrlController.dispose();
    super.dispose();
  }
}