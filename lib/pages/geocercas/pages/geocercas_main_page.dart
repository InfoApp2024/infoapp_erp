import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:infoapp/core/branding/branding_service.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import '../controllers/geocercas_controller.dart';
import 'geocercas_map_page.dart';
import 'geocercas_registros_page.dart';

class GeocercasMainPage extends StatelessWidget {
  const GeocercasMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Usar la instancia global del controlador en lugar de crear una nueva
    return Consumer<GeocercasController>(
      builder: (context, controller, _) {
        // Inicializar solo una vez
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!controller.isMonitoring) {
            controller.cargarGeocercas();
            // En web solo cargamos el mapa — el monitoreo GPS es exclusivo de móvil
            if (!kIsWeb) {
              controller.iniciarMonitoreo();
            }
          }
        });
        
        return const _GeocercasMainContentView();
      },
    );
  }
}

class _GeocercasMainContentView extends StatefulWidget {
  const _GeocercasMainContentView();

  @override
  State<_GeocercasMainContentView> createState() =>
      _GeocercasMainContentViewState();
}

class _GeocercasMainContentViewState extends State<_GeocercasMainContentView> {
  int _currentIndex = 0;
  final List<Widget> _pages = const [
    GeocercasMapPage(),
    GeocercasRegistrosPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final branding = BrandingService();

    // 1. Permiso de VER - Gatekeeper para acceso al módulo
    final bool canView = PermissionStore.instance.can('geocercas', 'ver');
    if (!canView) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Geocercas'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No tienes permiso para acceder al módulo de geocercas',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: branding.primaryColor,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Registros'),
        ],
      ),
    );
  }
}
