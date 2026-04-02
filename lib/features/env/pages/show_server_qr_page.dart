import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:infoapp/core/utils/download_utils.dart' as dl;

class ShowServerQrPage extends StatefulWidget {
  const ShowServerQrPage({super.key});

  @override
  State<ShowServerQrPage> createState() => _ShowServerQrPageState();
}

class _ShowServerQrPageState extends State<ShowServerQrPage> {
  String? _selectedRoot;
  final GlobalKey _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedRoot = ServerConfig.instance.currentRoot ?? ServerConfig.instance.apiRoot().replaceAll('/API_Infoapp', '');
  }

  String _buildPayload(String root) {
    final r = root.trim().replaceAll(RegExp(r"/+$"), '');
    final uri = Uri(
      scheme: 'infoapp',
      host: 'env',
      queryParameters: {'api_root': r},
    ).toString();
    return uri;
  }

  Future<void> _downloadQr() async {
    final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: kIsWeb ? 2 : 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    await dl.saveBytes('infoapp_server_qr.png', byteData.buffer.asUint8List(), mimeType: 'image/png');
  }

  @override
  Widget build(BuildContext context) {
    final root = _selectedRoot ?? ServerConfig.instance.apiRoot().replaceAll('/API_Infoapp', '');
    final payload = _buildPayload(root);

    return Scaffold(
      appBar: AppBar(title: const Text('QR de servidor')), 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Text(
                root,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
              ),
              child: RepaintBoundary(
                key: _qrKey,
                child: QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: kIsWeb ? 300 : 240,
                  gapless: false,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _downloadQr,
              icon: const Icon(Icons.download),
              label: const Text('Descargar QR'),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Escanea este QR con la app móvil para seleccionar el servidor.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}