import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:infoapp/main.dart';
import '../models/inspeccion_model.dart';
import '../providers/inspecciones_provider.dart';
import '../widgets/inspeccion_form.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import '../widgets/dialogo_crear_servicio.dart';
import 'package:infoapp/pages/servicios/forms/servicio_detail_page.dart';
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:infoapp/pages/servicios/controllers/servicios_controller.dart'; // ✅ Controller import

class InspeccionDetallePage extends StatefulWidget {
  final int inspeccionId;

  const InspeccionDetallePage({super.key, required this.inspeccionId});

  @override
  State<InspeccionDetallePage> createState() => _InspeccionDetallePageState();
}

class _InspeccionDetallePageState extends State<InspeccionDetallePage> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _esClienteRol = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkRol();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InspeccionesProvider>(context, listen: false)
          .cargarInspeccion(widget.inspeccionId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkRol() async {
    final userData = await AuthService.getUserData();
    if (userData != null) {
      final rol = userData['rol']?.toString().toLowerCase() ?? '';
      if (rol == 'cliente') {
        if (mounted) setState(() => _esClienteRol = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InspeccionesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final inspeccion = provider.inspeccionSeleccionada;

        if (inspeccion == null || inspeccion.id != widget.inspeccionId) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle de Inspección')),
            body: Center(
              child: provider.error != null
                  ? Text('Error: ${provider.error}')
                  : const Text('No se encontró la inspección'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(inspeccion.numeroInspeccionFormateado),
            actions: [
              if (!inspeccion.estaFinalizada)
                IconButton(
                  key: const ValueKey('edit_inspection_btn'),
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editarInspeccion(context, inspeccion),
                  tooltip: 'Editar inspección',
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'General'),
                Tab(text: 'Actividades'),
                Tab(text: 'Evidencias'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildGeneralTab(inspeccion),
              _buildActividadesTab(inspeccion),
              _buildEvidenciasTab(inspeccion),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGeneralTab(InspeccionModel inspeccion) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            'Información Básica',
            [
              _buildRow('Estado:', inspeccion.estadoNombre ?? 'N/A', 
                color: inspeccion.estadoColor != null ? Color(int.parse('0xFF${inspeccion.estadoColor!.replaceAll('#', '')}')) : null),
              _buildRow('Sitio:', inspeccion.sitio ?? 'N/A'),
              _buildRow('Fecha:', inspeccion.fechaInspe ?? 'N/A'),
              _buildRow('Creado por:', inspeccion.creadoPorNombre ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCard(
            'Equipo',
            [
              _buildRow('Nombre:', inspeccion.equipoNombre ?? 'N/A'),
              _buildRow('Placa:', inspeccion.equipoPlaca ?? 'N/A'),
              _buildRow('Modelo:', inspeccion.equipoModelo ?? 'N/A'),
              _buildRow('Marca:', inspeccion.equipoMarca ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCard(
            'Inspectores',
            [
              if (inspeccion.inspectores != null && inspeccion.inspectores!.isNotEmpty)
                ...inspeccion.inspectores!.map((inspector) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [const Icon(Icons.person, size: 16), const SizedBox(width: 8), Text(inspector.nombre ?? 'Sin nombre')]),
                ))
              else
                const Text('Sin inspectores asignados'),
            ],
          ),
           const SizedBox(height: 16),
          _buildCard(
            'Sistemas',
            [
               if (inspeccion.sistemas != null && inspeccion.sistemas!.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: inspeccion.sistemas!.map((sistema) => Chip(
                    label: Text(sistema.nombre ?? 'Sin nombre'),
                    backgroundColor: Colors.grey[200],
                  )).toList(),
                )
              else
                const Text('Sin sistemas seleccionados'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActividadesTab(InspeccionModel inspeccion) {
    if (inspeccion.actividades == null || inspeccion.actividades!.isEmpty) {
      return const Center(child: Text('No hay actividades registradas'));
    }

    final actividadesVisibles = List<ActividadInspeccionModel>.from(inspeccion.actividades!);
    actividadesVisibles.sort((a, b) {
      final dateA = a.createdAt != null ? DateTime.tryParse(a.createdAt!) : null;
      final dateB = b.createdAt != null ? DateTime.tryParse(b.createdAt!) : null;
      
      if (dateA == null && dateB == null) {
        return (a.id ?? 0).compareTo(b.id ?? 0);
      }
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      
      final dateCompare = dateB.compareTo(dateA);
      if (dateCompare != 0) return dateCompare;
      
      // Fallback estable si las fechas son iguales
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

    return ListView.builder(
      itemCount: actividadesVisibles.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final actividad = actividadesVisibles[index];
        final tieneServicio = actividad.servicioId != null;
        final estaAutorizada = actividad.autorizada == true;
        final estaEliminada = actividad.estaEliminada;
        
        return Card(
          key: ValueKey(actividad.id),
          color: estaEliminada ? Colors.red.shade50 : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: estaEliminada 
                  ? Colors.red 
                  : (tieneServicio 
                      ? Colors.blue 
                      : (estaAutorizada ? Colors.green : Colors.orange)),
              child: Icon(
                estaEliminada
                    ? Icons.delete_outline
                    : (tieneServicio 
                        ? Icons.build 
                        : (estaAutorizada ? Icons.check : Icons.pending)),
                color: Colors.white,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    actividad.actividadNombre ?? 'Actividad desconocida',
                    style: TextStyle(
                      decoration: estaEliminada ? TextDecoration.lineThrough : null,
                      color: estaEliminada ? Colors.grey[600] : null,
                      fontWeight: estaEliminada ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                ),
                if (estaEliminada)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ELIMINADA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (actividad.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Registrada: ${_formatearFecha(actividad.createdAt!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (actividad.registradoPorNombre != null &&
                    actividad.registradoPorNombre != 'N/A')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Registrada por: ${actividad.registradoPorNombre}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              if (estaEliminada && actividad.eliminadoPorNombre != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.person_remove_outlined, size: 12, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        'Eliminada por: ${actividad.eliminadoPorNombre}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              if (actividad.autorizadoPorNombre != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user, size: 12, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Autorizada por: ${actividad.autorizadoPorNombre}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actividad.avaladorNombre != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Icon(Icons.person_pin, size: 12, color: Colors.orange[800]),
                        const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Avalada por (Cliente): ${actividad.avaladorNombre}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ],
                    ),
                  ),
                if (actividad.fechaAutorizacion != null && tieneServicio)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Aprobada: ${_formatearFecha(actividad.fechaAutorizacion!)}${actividad.aprobadoPorNombre != null ? " por ${actividad.aprobadoPorNombre}" : ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ],
                    ),
                  ),
                if (actividad.notas != null && actividad.notas!.isNotEmpty && !estaEliminada)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Notas: ${actividad.notas}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                    ),
                  ),
                if (tieneServicio)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: InkWell(
                            onTap: _esClienteRol ? null : () {
                               Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ServicioDetailPage(
                                    servicio: ServicioModel(id: actividad.servicioId),
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              '${actividad.servicioNumeroFormateado}${actividad.servicioFecha != null ? " (${_formatearFechaSoloDia(actividad.servicioFecha!)})" : ""}',
                              style: TextStyle(
                                color: _esClienteRol ? Colors.grey : Colors.blue,
                                fontWeight: FontWeight.bold,
                                decoration: _esClienteRol ? TextDecoration.none : TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (estaEliminada && actividad.notas != null && actividad.notas!.isNotEmpty)
                   Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.note_alt_outlined, size: 12, color: Colors.red[300]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Nota de eliminación disponible',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red[700],
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: _buildActividadTrailing(actividad, inspeccion, isMobile: MediaQuery.of(context).size.width < 600),
          ),
        );
      },
    );
  }

  void _mostrarDialogoNota(BuildContext context, ActividadInspeccionModel actividad) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nota de Actividad',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(actividad.notas ?? 'No hay notas registradas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget? _buildActividadTrailing(ActividadInspeccionModel actividad, InspeccionModel inspeccion, {bool isMobile = false}) {
  final esFinalizada = inspeccion.estaFinalizada;

    if (actividad.estaEliminada) {
      if (actividad.notas != null && actividad.notas!.isNotEmpty) {
        return ElevatedButton.icon(
          key: ValueKey('ver_nota_btn_${actividad.id}'),
          onPressed: () => _mostrarDialogoNota(context, actividad),
          icon: const Icon(Icons.visibility, size: 18),
          label: Text(isMobile ? 'Nota' : 'Ver nota'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            foregroundColor: Colors.black87,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
          ),
        );
      }
      return null;
    }
    final tieneServicio = actividad.servicioId != null;
    final estaAutorizada = actividad.autorizada == true;

    if (tieneServicio) {
      // Ya tiene servicio - mostrar botón para ver
      return IconButton(
        key: ValueKey('ver_servicio_${actividad.id}'),
        icon: Icon(
          Icons.open_in_new, 
          color: _esClienteRol ? Colors.grey : Colors.blue
        ),
        onPressed: _esClienteRol ? null : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServicioDetailPage(
                servicio: ServicioModel(id: actividad.servicioId),
              ),
            ),
          );
        },
        tooltip: _esClienteRol ? 'Acceso restringido' : 'Ver servicio',
      );
    } else if (estaAutorizada) {
      // Autorizada sin servicio - mostrar botón eliminar y crear servicio
      if (esFinalizada) return null;
      return Row(
        key: ValueKey('trailing_row_autorizada_${actividad.id}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('eliminar_autorizada_${actividad.id}'),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Eliminar actividad',
            onPressed: () => _confirmarEliminacion(context, actividad),
          ),
          if (!isMobile) const SizedBox(width: 8),
          if (isMobile)
            IconButton(
              key: ValueKey('crear_servicio_btn_mobile_${actividad.id}'),
              onPressed: () => _mostrarDialogoCrearServicio(actividad, inspeccion),
              icon: const Icon(Icons.add_circle, color: Colors.green),
              tooltip: 'Crear Servicio',
            )
          else
            FilledButton.icon(
              key: ValueKey('crear_servicio_btn_${actividad.id}'),
              onPressed: () => _mostrarDialogoCrearServicio(actividad, inspeccion),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Crear Servicio'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      );
    } else {
      // No autorizada - mostrar botón eliminar y autorizar
      if (esFinalizada) return null;
      return Row(
        key: ValueKey('trailing_row_pendiente_${actividad.id}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('eliminar_pendiente_${actividad.id}'),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Eliminar actividad',
            onPressed: () => _confirmarEliminacion(context, actividad),
          ),
          if (!isMobile) const SizedBox(width: 8),
          if (isMobile)
            IconButton(
              key: ValueKey('autorizar_btn_mobile_${actividad.id}'),
              onPressed: () => _confirmarAutorizacion(context, actividad),
              icon: const Icon(Icons.check_circle, color: Colors.blue),
              tooltip: 'Autorizar',
            )
          else
            FilledButton.icon(
              key: ValueKey('autorizar_btn_${actividad.id}'),
              onPressed: () => _confirmarAutorizacion(context, actividad),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Autorizar'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      );
    }
  }

  void _confirmarEliminacion(BuildContext context, ActividadInspeccionModel actividad) async {
    final TextEditingController notaController = TextEditingController();
    
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Actividad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Está seguro de eliminar la actividad "${actividad.actividadNombre}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: notaController,
              decoration: const InputDecoration(
                labelText: 'Motivo de eliminación',
                hintText: 'Ingrese la razón...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (notaController.text.trim().isEmpty) {
                MyApp.showSnackBar('Por favor ingrese un motivo', backgroundColor: Colors.red);
                return;
              }
              Navigator.pop(context, true);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      final provider = Provider.of<InspeccionesProvider>(context, listen: false);
      final exito = await provider.eliminarActividad(
        inspeccionId: widget.inspeccionId,
        inspeccionActividadId: actividad.id!,
        notas: notaController.text.trim(),
        silencioso: true,
      );

      if (mounted) {
        if (exito) {
          MyApp.showSnackBar('Actividad eliminada correctamente', backgroundColor: Colors.green);
        } else {
          MyApp.showSnackBar(provider.error ?? 'Error al eliminar actividad', backgroundColor: Colors.red);
        }
      }
    }
  }

  void _confirmarAutorizacion(BuildContext context, ActividadInspeccionModel actividad) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Confirmar Autorización',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Estás seguro de autorizar esta actividad?'),
            const SizedBox(height: 8),
            Text(
              actividad.actividadNombre ?? 'Sin nombre',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Esta acción permitirá la creación de un servicio basado en esta actividad.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _autorizarActividad(context, actividad.id!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Autorizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoCrearServicio(
    ActividadInspeccionModel actividad,
    InspeccionModel inspeccion,
  ) async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DialogoCrearServicio(
        actividadNombre: actividad.actividadNombre ?? 'Actividad',
        equipoNombre: inspeccion.equipoNombre ?? 'Equipo',
        equipoEmpresa: inspeccion.equipoEmpresa,
        clienteId: inspeccion.clienteId,
        autorizadoPorId: actividad.autorizadoPorId,
      ),
    );

    if (resultado != null && mounted) {
      await _crearServicioDesdeActividad(actividad.id!, resultado);
    }
  }

  Future<void> _crearServicioDesdeActividad(
    int actividadId,
    Map<String, dynamic> datos,
  ) async {
    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creando servicio...'),
                ],
              ),
            ),
          ),
        ),
      );

      final provider = Provider.of<InspeccionesProvider>(context, listen: false);
      final resultado = await provider.crearServicioDesdeActividad(
        inspeccionActividadId: actividadId,
        autorizadoPor: datos['autorizado_por'] as int,
        ordenCliente: datos['orden_cliente'],
        tipoMantenimiento: datos['tipo_mantenimiento'],
        centroCosto: datos['centro_costo'],
        estadoId: datos['estado_id'] as int,
        clienteId: datos['cliente_id'] as int?,
        nota: datos['nota'],
      );

      // Cerrar loading
      if (!mounted) return;
      Navigator.of(context).pop();

      if (resultado != null) {
        // Éxito
        MyApp.showSnackBar(
          '✅ Servicio ${resultado['numero_servicio_formateado']} creado exitosamente',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        );

        // ✅ REFRESCAR LISTA DE SERVICIOS
        // Como el servicio se crea desde otro módulo, necesitamos avisar al controlador de servicios
        // para que lo agregue a la lista localmente sin recargar todo.
        try {
          if (resultado['servicio_id'] != null) {
            final serviciosController = Provider.of<ServiciosController>(context, listen: false);
            // Usamos el método que el usuario agregó recientemente
            await serviciosController.refrescarServicioEspecifico(resultado['servicio_id'] as int);
          }
        } catch (e) {
          debugPrint('No se pudo refrescar servicios: $e');
        }

      } else {
        // Error
        MyApp.showSnackBar('❌ Error al crear servicio', backgroundColor: Colors.red, duration: const Duration(seconds: 5));
      }
    } catch (e) {
      // Cerrar loading si está abierto
      if (mounted) Navigator.of(context).pop();
      
      MyApp.showSnackBar('❌ Error: $e', backgroundColor: Colors.red, duration: const Duration(seconds: 5));
    }
  }

  Widget _buildEvidenciasTab(InspeccionModel inspeccion) {
     if (inspeccion.evidencias == null || inspeccion.evidencias!.isEmpty) {
      return const Center(child: Text('No hay evidencias registradas'));
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: inspeccion.evidencias!.length,
      itemBuilder: (context, index) {
        final evidencia = inspeccion.evidencias![index];
        final rutaImagen = evidencia.rutaImagen ?? '';
        final baseUrl = ServerConfig.instance.apiRoot();
        final imageUrl = '$baseUrl/$rutaImagen';

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _mostrarImagenGrande(context, imageUrl, evidencia.comentario),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 40, color: Colors.grey),
                              SizedBox(height: 4),
                              Text('No imagen', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / 
                                loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  evidencia.comentario != null && evidencia.comentario!.isNotEmpty 
                      ? evidencia.comentario! 
                      : 'Sin comentario',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarImagenGrande(BuildContext context, String imageUrl, String? comentario) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            if (comentario != null && comentario.isNotEmpty)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    comentario,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatearFecha(String fechaStr) {
    try {
      DateTime fecha = DateTime.parse(fechaStr);
      if (!fechaStr.endsWith('Z') && !fechaStr.contains('+')) {
        fecha = DateTime.parse('${fechaStr.replaceFirst(' ', 'T')}Z');
      }
      return DateFormat('dd/MM/yyyy HH:mm').format(fecha.toLocal());
    } catch (e) {
      return fechaStr;
    }
  }

  String _formatearFechaSoloDia(String fechaStr) {
    try {
      DateTime fecha = DateTime.parse(fechaStr);
      if (!fechaStr.endsWith('Z') && !fechaStr.contains('+')) {
        fecha = DateTime.parse('${fechaStr.replaceFirst(' ', 'T')}Z');
      }
      return DateFormat('dd/MM/yyyy').format(fecha.toLocal());
    } catch (e) {
      return fechaStr;
    }
  }

  void _editarInspeccion(BuildContext context, InspeccionModel inspeccion) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspeccionForm(
          inspeccion: inspeccion,
          onSaved: () {
            // No es necesario llamar cargarInspeccion aquí ya que el provider
            // lo hace automáticamente de forma asíncrona al actualizar.
          },
        ),
      ),
    );
  }
  
  void _autorizarActividad(BuildContext context, int id) async {
    try {
      final provider = Provider.of<InspeccionesProvider>(context, listen: false);
      final exito = await provider.autorizarActividad(inspeccionActividadId: id, autorizada: true);
      
      if (exito) {
        MyApp.showSnackBar('✅ Actividad aprobada exitosamente', backgroundColor: Colors.green, duration: const Duration(seconds: 5));
      } else {
        MyApp.showSnackBar('❌ Error al aprobar actividad', backgroundColor: Colors.red, duration: const Duration(seconds: 5));
      }
    } catch (e) {
      MyApp.showSnackBar('❌ Error: $e', backgroundColor: Colors.red, duration: const Duration(seconds: 5));
    }
  }
}
