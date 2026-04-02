// lib/pages/home/services/navigation_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart'; // Añadir import
import '../models/navigation_item_model.dart';
import '../../campos_adicionales_page.dart';
import '../../estados_transiciones_page.dart';
import '../../servicios/pages/servicios_list_page.dart';
import '../../equipos/pages/equipos_list_page.dart';
import 'package:infoapp/core/branding/branding_page.dart';
import '../../inventory/pages/inventory_main_page.dart';
// ✅ IMPORTS PARA STAFF - AL INICIO DEL ARCHIVO
import '../../staff/pages/staff_pages.dart';
import '../../staff/presentation/staff_presentation.dart';
// ✅ Import para Plantillas
import '../../plantillas/views/plantillas_list_view.dart';
import '../../admin/admin_user_console.dart';
import '../../clientes/pages/clientes_list_page.dart';
import 'package:infoapp/features/chatbot/presentation/pages/chat_page.dart';
import 'package:infoapp/features/chatbot/presentation/pages/ai_settings_page.dart';
import '../../../pages/geocercas/pages/geocercas_main_page.dart';
import '../../../ui/dashboard/dashboard_screen.dart';
import '../../inspecciones/pages/inspecciones_page.dart';
import '../../actividades/pages/actividades_list_page.dart';
import '../../accounting/pages/gestion_financiera_page.dart';
import '../../accounting/pages/facturacion_config_page.dart';

class NavigationService {
  List<NavigationItem> getMenuItems(bool esAdmin) {
    //     print('🔧 NavigationService: Generando items de menú (Admin: $esAdmin)'); // DEBUG

    // Si no es admin, se aplicarán filtros más adelante o en el Drawer
    // Pero mantenemos una lista base consistente

    List<NavigationItem> items = [
      NavigationItem(
        id: 'Servicios',
        title: 'Servicios',
        icon: PhosphorIcons.wrench(),
      ),
      NavigationItem(
        id: 'Inventario',
        title: 'Inventario',
        icon: PhosphorIcons.package(),
      ),
      NavigationItem(
        id: 'Inspecciones',
        title: 'Inspecciones',
        icon: PhosphorIcons.clipboardText(),
      ),
      NavigationItem(
        id: 'Plantillas',
        title: 'Plantillas',
        icon: PhosphorIcons.fileText(),
      ),
      NavigationItem(
        id: 'Usuarios',
        title: 'Usuarios',
        icon: PhosphorIcons.userCircle(),
      ),
      NavigationItem(
        id: 'Geocercas',
        title: 'Geocercas',
        icon: PhosphorIcons.mapPin(),
      ),
      NavigationItem(
        id: 'Actividades',
        title: 'Actividades',
        icon: PhosphorIcons.listChecks(),
      ),
      NavigationItem(
        id: 'Personal',
        title: 'Personal',
        icon: PhosphorIcons.users(),
      ),
      NavigationItem(
        id: 'Registro de Activos',
        title: 'Registro de Activos',
        icon: PhosphorIcons.factory(),
      ),
      NavigationItem(
        id: 'Gestión Financiera',
        title: 'Gestión Financiera',
        icon: PhosphorIcons.coins(),
      ),
    ];

    if (esAdmin && kIsWeb) {
      items.add(
        NavigationItem(
          id: 'Ajustes',
          title: 'Ajustes',
          icon: Icons.settings,
          isExpansion: true,
          adminOnly: true,
          children: [
            NavigationItem(
              id: 'Campos adicionales',
              title: 'Campos adicionales',
              icon: Icons.add_box,
            ),
            NavigationItem(
              id: 'Estados y transiciones',
              title: 'Estados y transiciones',
              icon: Icons.swap_horiz,
            ),
            NavigationItem(
              id: 'Branding',
              title: 'Branding',
              icon: Icons.palette,
            ),
            NavigationItem(
              id: 'Configuración Facturación',
              title: 'Configuración Facturación',
              icon: Icons.receipt_long,
            ),
          ],
        ),
      );
    }

    //     print('📋 Items generados: ${items.map((i) => i.title).toList()}'); // DEBUG
    return items;
  }

  Widget getViewForRoute(String route, String nombreUsuario) {
    //     print('🎯 NavigationService: Obteniendo vista para ruta "$route"'); // DEBUG

    switch (route) {
      case 'Geocercas':
        return const GeocercasMainPage();
      case 'Dashboard':
        return const DashboardScreen();
      case 'Campos adicionales':
        //         print('   → Devolviendo CamposAdicionalesPage'); // DEBUG
        return const CamposAdicionalesPage();
      case 'Estados y transiciones':
        //         print('   → Devolviendo EstadosTransicionesPage'); // DEBUG
        return const EstadosTransicionesPage();
      case 'Servicios':
        //         print('   → Devolviendo ServiciosListPage'); // DEBUG
        return const ServiciosListPage();
      case 'Asistente IA':
        return const ChatPage();
      case 'Configuración IA':
        return const AISettingsPage();
      case 'Inventario':
        //         print('   → Devolviendo InventoryMainPage'); // DEBUG
        return const InventoryMainPage();
      case 'Plantillas':
        //         print('   → Devolviendo PlantillasListView'); // DEBUG
        return const PlantillasListView();
      case 'Clientes':
        return const ClientesListPage();
      case 'Usuarios':
        return const AdminUserConsolePage();
      // ✅ NUEVO CASO PARA INSPECCIONES
      case 'Inspecciones':
        return const InspeccionesPage();
      case 'Actividades':
        return const ActividadesListPage();
      // ✅ NUEVO CASO PARA STAFF/PERSONAL
      case 'Personal':
      case 'Staff':
        //         print('   → Devolviendo StaffListPage'); // DEBUG
        return _buildStaffPageWithDependencies();
      case 'Registro de Activos':
        //         print('   → Devolviendo EquiposListPage'); // DEBUG
        return const EquiposListPage();
      case 'Branding':
        //         print('   → Devolviendo BrandingPage'); // DEBUG
        return const BrandingPage();
      case 'Gestión Financiera':
        return const GestionFinancieraPage();
      case 'Configuración Facturación':
        return const FacturacionConfigPage();
      default:
        //         print('   → Ruta no encontrada, devolviendo default'); // DEBUG
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text("Ruta no encontrada: $route"),
              const SizedBox(height: 8),
              const Text("Selecciona una opción del menú"),
            ],
          ),
        );
    }
  }

  // ✅ MÉTODO PRIVADO PARA MANEJAR DEPENDENCIAS DE STAFF
  Widget _buildStaffPageWithDependencies() {
    try {
      // Verificar si las dependencias ya están registradas
      if (!Get.isRegistered<StaffController>()) {
        // Aplicar el binding del módulo Staff
        StaffBinding().dependencies();
        //         print('✅ StaffBinding aplicado desde NavigationService');
      }

      return const StaffListPage();
    } catch (e) {
      //       print('❌ Error cargando Staff desde NavigationService: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar el módulo de Personal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Error: $e',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }
}
