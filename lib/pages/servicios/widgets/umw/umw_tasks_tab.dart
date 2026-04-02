import 'package:flutter/material.dart';
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:infoapp/pages/servicios/widgets/seccion_operaciones.dart';
import 'package:flutter/foundation.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import 'package:infoapp/pages/servicios/forms/widgets/campos_adicionales.dart';
import 'package:infoapp/pages/servicios/models/servicio_staff_model.dart';
import 'package:infoapp/pages/servicios/models/servicio_repuesto_model.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class UmwTasksTab extends StatefulWidget {
  final ServicioModel servicio;
  final int? actividadId;
  final bool estaBloqueado;
  final GlobalKey<CamposAdicionalesServiciosState>? camposAdicionalesKey;
  final VoidCallback? onChanged;
  final List<ServicioStaffModel>? staffAsignado;
  final List<ServicioRepuestoModel>? repuestosAsignados;

  const UmwTasksTab({
    super.key,
    required this.servicio,
    this.actividadId,
    required this.estaBloqueado,
    this.camposAdicionalesKey,
    this.onChanged,
    this.staffAsignado,
    this.repuestosAsignados,
    this.onGestionarStaff,
    this.onGestionarRepuestos,
  });

  final Function(int?)? onGestionarStaff;
  final Function(int?)? onGestionarRepuestos;

  @override
  State<UmwTasksTab> createState() => _UmwTasksTabState();
}

class _UmwTasksTabState extends State<UmwTasksTab> {
  Map<int, dynamic> _valoresCamposAdicionales = {};
  Map<int, dynamic>? _valoresIniciales; // NUEVO: Para detectar cambios
  bool _camposAdicionalesLoaded = false;

  @override
  void didUpdateWidget(covariant UmwTasksTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el estadoId cambia, reiniciamos el trackeo para cargar el nuevo baseline
    if (widget.servicio.estadoId != oldWidget.servicio.estadoId) {
      _camposAdicionalesLoaded = false;
      _valoresIniciales = null;
    }
  }

  bool get _hasChanges {
    if (!_camposAdicionalesLoaded || _valoresIniciales == null) return false;
    return !mapEquals(_valoresIniciales, _valoresCamposAdicionales);
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna Izquierda: Operaciones (Mayor peso visual)
                Expanded(
                  flex: 3,
                  child: SeccionOperaciones(
                    servicio: widget.servicio,
                    actividadId: widget.actividadId,
                    estaBloqueado: widget.estaBloqueado,
                    staffAsignado: widget.staffAsignado ?? [],
                    repuestosAsignados: widget.repuestosAsignados ?? [],
                    onGestionarStaff: widget.onGestionarStaff,
                    onGestionarRepuestos: widget.onGestionarRepuestos,
                  ),
                ),

                const SizedBox(width: 24),

                // Columna Derecha: Campos Adicionales
                if (widget.servicio.estadoId != null &&
                    widget.camposAdicionalesKey != null)
                  Expanded(
                    flex: 2,
                    child: Card(
                      elevation: 3,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: _buildSeccionCamposAdicionales(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        // Layout Móvil (Columnar)
        return SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Sección de Operaciones (Tareas)
              SeccionOperaciones(
                servicio: widget.servicio,
                actividadId: widget.actividadId,
                estaBloqueado: widget.estaBloqueado,
                staffAsignado: widget.staffAsignado ?? [],
                repuestosAsignados: widget.repuestosAsignados ?? [],
                onGestionarStaff: widget.onGestionarStaff,
                onGestionarRepuestos: widget.onGestionarRepuestos,
              ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),

              // 2. Sección de Campos Adicionales
              // Solo mostrar si hay estado definido
              if (widget.servicio.estadoId != null &&
                  widget.camposAdicionalesKey != null)
                _buildSeccionCamposAdicionales(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeccionCamposAdicionales() {
    final store = PermissionStore.instance;
    final canView = store.can('servicios_campos_adicionales', 'ver');

    // Usamos el estado actual del servicio para cargar los campos
    // Nota: Si el estado cambia en el padre, este widget se reconstruye y actualiza el ID
    final estadoId = widget.servicio.estadoId;

    if (estadoId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Text(
              'Informacin Adicional',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (canView) ...[
          FutureBuilder<bool>(
            future: ConnectivityService.instance.checkNow(),
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? true;
              if (!isOnline && !kIsWeb) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Datos almacenados sin conexin. Cambios se guardarn para sincronizar.',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
        // Usamos Offstage para que el widget se construya y VALIDE aunque no se vea
        Offstage(
          offstage: !canView,
          child: CamposAdicionalesServicios(
            key: widget.camposAdicionalesKey,
            servicioId: widget.servicio.id,
            estadoId: estadoId,
            valoresCampos: _valoresCamposAdicionales,
            onValoresChanged: (valores) {
              setState(() => _valoresCamposAdicionales = valores);
              
              // Ignorar si an no termina la carga inicial o si los valores son idnticos
              if (!_camposAdicionalesLoaded) {
                 return;
              }
              if (mapEquals(_valoresCamposAdicionales, valores)) return;

              widget.onChanged?.call(); // Notificar cambio al padre
            },
            enabled: !widget.estaBloqueado,
            loadValuesOnInit: true,
            onLoaded: () {
               if (mounted) {
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                   if (mounted) {
                     setState(() {
                       _camposAdicionalesLoaded = true;
                       _valoresIniciales = Map.from(_valoresCamposAdicionales);
                     });
                   }
                 });
               }
            },
          ),
        ),
        if (canView)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: (widget.estaBloqueado || !_hasChanges)
                    ? null
                    : () async {
                        if (widget.camposAdicionalesKey?.currentState != null) {
                          // Validar antes de guardar
                          if (widget.camposAdicionalesKey!.currentState!.validarCamposObligatorios()) {
                             final success = await widget.camposAdicionalesKey!.currentState!.guardarCamposAdicionales();
                             if (success && mounted) {
                               setState(() {
                                 _valoresIniciales = Map.from(_valoresCamposAdicionales);
                               });
                             }
                          }
                        }
                      },
                icon: Icon(PhosphorIcons.floppyDisk(), size: 18),
                label: const Text('Guardar Campos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  foregroundColor: Theme.of(context).primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  // Estilo cuando está deshabilitado
                  disabledBackgroundColor: Colors.grey.shade100,
                  disabledForegroundColor: Colors.grey.shade400,
                ),
              ),
            ),
          ),
        if (!canView)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.lock, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Campos adicionales ocultos por permisos (se validarán reglas obligatorias al guardar).',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
