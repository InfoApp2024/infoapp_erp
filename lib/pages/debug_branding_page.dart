// lib/pages/debug_branding_page.dart
// ✅ PÁGINA TEMPORAL PARA DEBUGGEAR EL BRANDING

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infoapp/core/branding/branding_service.dart';
import 'package:infoapp/core/branding/branding_logo.dart';
import 'package:infoapp/utils/net_error_messages.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';

class DebugBrandingPage extends StatefulWidget {
  const DebugBrandingPage({super.key});

  @override
  State<DebugBrandingPage> createState() => _DebugBrandingPageState();
}

class _DebugBrandingPageState extends State<DebugBrandingPage> {
  final brandingService = BrandingService();
  bool _autoRefresh = false;

  @override
  void initState() {
    super.initState();
    _loadBranding();
  }

  Future<void> _loadBranding() async {
    await brandingService.loadBranding();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Branding'),
        backgroundColor: brandingService.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Switch(
            value: _autoRefresh,
            onChanged: (value) {
              setState(() {
                _autoRefresh = value;
              });
              if (value) {
                _startAutoRefresh();
              }
            },
            activeThumbColor: Colors.white,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: brandingService,
        builder: (context, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ ESTADO GENERAL
                _buildStatusCard(),
                const SizedBox(height: 16),

                // ✅ PRUEBAS DE LOGO
                _buildLogoTestCard(),
                const SizedBox(height: 16),

                // ✅ INFORMACIÓN DETALLADA
                _buildDetailCard(),
                const SizedBox(height: 16),

                // ✅ ACCIONES DE DEBUG
                _buildActionsCard(),
                const SizedBox(height: 16),

                // ✅ PRUEBA DE URL DIRECTA
                _buildDirectUrlTestCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  brandingService.isLoaded ? Icons.check_circle : Icons.error,
                  color: brandingService.isLoaded ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Estado del Branding',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Cargado', brandingService.isLoaded),
            _buildStatusRow('Cargando', brandingService.isLoading),
            _buildStatusRow('Tiene Logo', brandingService.logoUrl != null),
            _buildStatusRow('Error', brandingService.lastError != null),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            status ? Icons.check : Icons.close,
            size: 16,
            color: status ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text('$label: ${status ? 'Sí' : 'No'}'),
        ],
      ),
    );
  }

  Widget _buildLogoTestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pruebas de Logo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                // ✅ Logo pequeño
                Column(
                  children: [
                    const BrandingLogo(width: 40, height: 40),
                    const SizedBox(height: 8),
                    const Text('40x40', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 20),

                // ✅ Logo mediano
                Column(
                  children: [
                    const BrandingLogo(width: 64, height: 64),
                    const SizedBox(height: 8),
                    const Text('64x64', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 20),

                // ✅ Logo grande
                Column(
                  children: [
                    const BrandingLogo(width: 80, height: 80),
                    const SizedBox(height: 8),
                    const Text('80x80', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información Detallada',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            _buildDetailRow(
              'Color Primario',
              '#${brandingService.primaryColor.value.toRadixString(16)}',
            ),
            _buildDetailRow('URL del Logo', brandingService.logoUrl ?? 'null'),
            _buildDetailRow(
              'Último Error',
              brandingService.lastError ?? 'ninguno',
            ),

            const SizedBox(height: 12),

            // ✅ Muestra del color
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: brandingService.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Color Primario',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copiado al portapapeles')),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                value,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    final canVer = PermissionStore.instance.can('branding', 'ver');
    final canActualizar = PermissionStore.instance.can('branding', 'actualizar');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones de Debug',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: canActualizar
                      ? () {
                          brandingService.forceReload();
                        }
                      : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recargar'),
                ),
                const SizedBox(width: 12),

                ElevatedButton.icon(
                  onPressed: canVer
                      ? () {
                          brandingService.printBrandingStatus();
                        }
                      : null,
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Log a Consola'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: canVer
                      ? () {
                          setState(() {});
                        }
                      : null,
                  icon: const Icon(Icons.update),
                  label: const Text('Actualizar Vista'),
                ),
                const SizedBox(width: 12),

                ElevatedButton.icon(
                  onPressed: canVer
                      ? () {
                          _testApiDirectly();
                        }
                      : null,
                  icon: const Icon(Icons.api),
                  label: const Text('Test API'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectUrlTestCard() {
    if (brandingService.logoUrl == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay URL de logo para probar'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prueba de URL Directa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            Text('URL: ${brandingService.logoUrl}'),
            const SizedBox(height: 12),

            // ✅ Imagen directa para debugging
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  brandingService.logoUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value:
                            loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 50, color: Colors.red),
                          const SizedBox(height: 8),
                          Text('Error: $error'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startAutoRefresh() {
    if (!_autoRefresh) return;

    Future.delayed(const Duration(seconds: 2), () {
      if (_autoRefresh && mounted) {
        brandingService.forceReload();
        _startAutoRefresh();
      }
    });
  }

  Future<void> _testApiDirectly() async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Probando API...')));

      await brandingService.forceReload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API probada. Ver logs en consola.')),
        );
      }
    } catch (e) {
      if (mounted) {
        NetErrorMessages.showNetError(context, e, contexto: 'probar API');
      }
    }
  }
}
