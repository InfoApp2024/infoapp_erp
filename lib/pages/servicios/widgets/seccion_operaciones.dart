import 'dart:async'; // ✅ NUEVO
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../models/operacion_model.dart';
import '../providers/operaciones_provider.dart';
import '../models/servicio_model.dart';
import '../models/servicio_staff_model.dart';
import '../models/servicio_repuesto_model.dart';
import '../services/servicio_operaciones_api_service.dart'; // ✅ CORREGIDO
import 'package:infoapp/features/auth/data/auth_service.dart'; // ✅ NUEVO

class SeccionOperaciones extends StatefulWidget {
  final ServicioModel servicio;
  final bool estaBloqueado;
  final int? actividadId;
  final List<ServicioStaffModel> staffAsignado;
  final List<ServicioRepuestoModel> repuestosAsignados;
  final Function(int?)? onGestionarStaff;
  final Function(int?)? onGestionarRepuestos;

  const SeccionOperaciones({
    super.key,
    required this.servicio,
    this.estaBloqueado = false,
    this.actividadId,
    this.staffAsignado = const [],
    this.repuestosAsignados = const [],
    this.onGestionarStaff,
    this.onGestionarRepuestos,
  });

  @override
  State<SeccionOperaciones> createState() => _SeccionOperacionesState();
}

class _SeccionOperacionesState extends State<SeccionOperaciones> {
  Timer? _timer; // ✅ CronÃ³metro dinÃ¡mico
  bool _canEditClosedOps = false;

  @override
  void initState() {
    super.initState();
    // Actualizar cada minuto para reflejar el tiempo transcurrido
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OperacionesProvider>().cargarOperaciones(
        widget.servicio.id!,
      );
    });
    _loadUserPermissions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserPermissions() async {
    final canEdit = await AuthService.canEditClosedOps();
    if (mounted) {
      setState(() => _canEditClosedOps = canEdit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OperacionesProvider>();
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          PhosphorIcons.listChecks(),
                          color: theme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Operaciones y Tareas Adicionales',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          PhosphorIcons.info(),
                          size: 18,
                          color: Colors.blue,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _mostrarAyudaVinculacion(context),
                      ),
                    ],
                  ),
                ),
                if (!widget.estaBloqueado)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: () => _mostrarGestionOperaciones(context),
                      icon: Icon(PhosphorIcons.pencilSimple(), size: 18),
                      label: const Text('Gestionar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                        foregroundColor: theme.primaryColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (provider.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (provider.operaciones.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      PhosphorIcons.maskHappy(),
                      size: 40,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay operaciones registradas para este servicio.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    provider.resumenProgreso,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.primaryColor,
                    ),
                  ),
                  Text(
                    '${(provider.totalOperaciones > 0 ? (provider.completadas / provider.totalOperaciones * 100).toInt() : 0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value:
                      provider.totalOperaciones > 0
                          ? provider.completadas / provider.totalOperaciones
                          : 0,
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 24),
              _buildGlobalSummary(),
              if (provider.operaciones.isNotEmpty) const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.operaciones.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final op = provider.operaciones[index];
                  return _buildOperacionItem(op, provider);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOperacionItem(OperacionModel op, OperacionesProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: op.estaFinalizada ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color:
              op.estaFinalizada ? Colors.grey.shade200 : Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _mostrarGestionOperaciones(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      child: Icon(
                        op.estaFinalizada
                            ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                            : PhosphorIcons.circle(),
                        color:
                            op.estaFinalizada
                                ? Colors.green
                                : Colors.grey.shade300,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            op.descripcion,
                            style: TextStyle(
                              fontWeight:
                                  op.estaFinalizada
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                              decoration:
                                  op.estaFinalizada
                                      ? TextDecoration.lineThrough
                                      : null,
                              color:
                                  op.estaFinalizada
                                      ? Colors.grey.shade500
                                      : Colors.black87,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                          if (op.isMaster) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                'OPERACIÓN MAESTRA',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          _buildTiempoConsumidoRow(op), // ✅ Cronómetro dinámico
                          if (op.excedeLimiteLogico) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  PhosphorIcons.warning(
                                    PhosphorIconsStyle.fill,
                                  ),
                                  size: 14,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '¡ATENCIÓN! Excede las 12 horas',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (op.observaciones != null &&
                              op.observaciones!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              op.observaciones!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                PhosphorIcons.user(),
                                size: 12,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  op.tecnicoNombre ??
                                      (widget.staffAsignado.any(
                                            (s) => s.operacionId == op.id,
                                          )
                                          ? widget.staffAsignado
                                              .firstWhere(
                                                (s) => s.operacionId == op.id,
                                              )
                                              .fullName
                                          : (widget.staffAsignado.isNotEmpty
                                              ? '${widget.staffAsignado.first.fullName} (G)'
                                              : 'Sin responsable')),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        op.tecnicoNombre != null
                                            ? Colors.grey.shade600
                                            : Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if (op.fechaInicio != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      PhosphorIcons.playCircle(),
                                      size: 12,
                                      color: Colors.blue.shade300,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Inicio: ${_formatDate(op.fechaInicio!)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              if (op.estaFinalizada && op.fechaFin != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      PhosphorIcons.checkCircle(),
                                      size: 12,
                                      color: Colors.green.shade300,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Fin: ${_formatDate(op.fechaFin!)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildResourceBadge(
                      icon: PhosphorIcons.users(),
                      count:
                          widget.staffAsignado
                              .where((s) => s.operacionId == op.id)
                              .length,
                      extraCount:
                          provider.operaciones.isNotEmpty &&
                                  op.id == provider.operaciones.first.id
                              ? widget.staffAsignado
                                  .where((s) => s.operacionId == null)
                                  .length
                              : 0,
                      label: 'Personal',
                      color: Colors.orange,
                    ),
                    _buildResourceBadge(
                      icon: PhosphorIcons.package(),
                      count:
                          widget.repuestosAsignados
                              .where((r) => r.operacionId == op.id)
                              .length,
                      extraCount:
                          provider.operaciones.isNotEmpty &&
                                  op.id == provider.operaciones.first.id
                              ? widget.repuestosAsignados
                                  .where((r) => r.operacionId == null)
                                  .length
                              : 0,
                      label: 'Repuestos',
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate.replaceFirst(' ', 'T')).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  void _mostrarGestionOperaciones(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => GestionOperacionesModal(
            servicio: widget.servicio,
            estaBloqueado: widget.estaBloqueado,
            actividadId: widget.actividadId,
            staffAsignado: widget.staffAsignado,
            repuestosAsignados: widget.repuestosAsignados,
            onGestionarStaff: widget.onGestionarStaff,
            onGestionarRepuestos: widget.onGestionarRepuestos,
          ),
    );
  }

  void _mostrarAyudaVinculacion(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(PhosphorIcons.info(), color: Colors.blue),
                const SizedBox(width: 10),
                const Text('¿Cómo vincular recursos?'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Para asociar un Repuesto o un Técnico a una operación específica:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildAyudaItem('1', 'Ve a la pestaña de "Recursos"'),
                _buildAyudaItem('2', 'Usa el botón "Gestionar" o "Agregar"'),
                _buildAyudaItem(
                  '3',
                  'Busca el campo "Vincular a:" en el selector',
                ),
                _buildAyudaItem('4', 'Selecciona la operación de la lista'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }

  Widget _buildAyudaItem(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            '$num.',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildGlobalSummary() {
    final globalStaff =
        widget.staffAsignado.where((s) => s.operacionId == null).length;
    final globalRepuestos =
        widget.repuestosAsignados.where((r) => r.operacionId == null).length;
    if (globalStaff == 0 && globalRepuestos == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.globe(),
                size: 16,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'Recursos sin vincular (Globales)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              if (globalStaff > 0)
                _buildSmallGlobalBadge(
                  PhosphorIcons.users(),
                  '$globalStaff Personal',
                  Colors.orange,
                ),
              if (globalRepuestos > 0)
                _buildSmallGlobalBadge(
                  PhosphorIcons.package(),
                  '$globalRepuestos Repuestos',
                  Colors.blue,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallGlobalBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceBadge({
    required IconData icon,
    required int count,
    int extraCount = 0,
    required String label,
    required Color color,
  }) {
    final total = count + extraCount;
    final hasResources = total > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasResources ? color.withOpacity(0.08) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasResources ? color.withOpacity(0.2) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$total $label${extraCount > 0 ? ' ($extraCount G)' : ''}',
            style: TextStyle(
              fontSize: 11,
              color: hasResources ? color.darken(0.1) : Colors.grey.shade500,
              fontWeight: total > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTiempoConsumidoRow(OperacionModel op) {
    final duracion = op.duracionCalculada;
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes % 60;

    String tiempoStr = '';
    if (horas > 0) {
      tiempoStr = '${horas}h ${minutos}m';
    } else if (minutos > 0) {
      tiempoStr = '${minutos}m';
    } else {
      tiempoStr = '${duracion.inSeconds % 60}s';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          PhosphorIcons.clock(
            op.estaFinalizada
                ? PhosphorIconsStyle.regular
                : PhosphorIconsStyle.bold,
          ),
          size: 14,
          color: op.estaFinalizada ? Colors.grey : Colors.blue,
        ),
        const SizedBox(width: 6),
        Text(
          'Tiempo Consumido: ',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        Text(
          tiempoStr,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color:
                op.estaFinalizada ? Colors.grey.shade700 : Colors.blue.shade700,
          ),
        ),
        if (!op.estaFinalizada) ...[
          const SizedBox(width: 6),
          _buildPulsingDot(),
        ],
      ],
    );
  }

  Widget _buildPulsingDot() {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
    );
  }
}

extension ColorDarken on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

class GestionOperacionesModal extends StatefulWidget {
  final ServicioModel servicio;
  final bool estaBloqueado;
  final int? actividadId;
  final List<ServicioStaffModel> staffAsignado;
  final List<ServicioRepuestoModel> repuestosAsignados;
  final Function(int?)? onGestionarStaff;
  final Function(int?)? onGestionarRepuestos;

  const GestionOperacionesModal({
    super.key,
    required this.servicio,
    this.estaBloqueado = false,
    this.actividadId,
    this.staffAsignado = const [],
    this.repuestosAsignados = const [],
    this.onGestionarStaff,
    this.onGestionarRepuestos,
  });

  @override
  State<GestionOperacionesModal> createState() =>
      _GestionOperacionesModalState();
}

class _GestionOperacionesModalState extends State<GestionOperacionesModal> {
  final TextEditingController _descController = TextEditingController();
  bool _isAdding = false;
  int? _selectedTecnicoId;
  DateTime _fechaInicioNueva = DateTime.now(); // ✅ NUEVO
  bool _canEditClosedOps = false; // ✅ NUEVO

  @override
  void initState() {
    super.initState();
    _loadUserPermissions(); // ✅ NUEVO
    // Pre-seleccionar el primer técnico (Responsable) si hay staff asignado
    if (widget.staffAsignado.isNotEmpty) {
      _selectedTecnicoId = widget.staffAsignado.first.staffId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OperacionesProvider>();
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 550),
        height: 750,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestionar Operaciones',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Añade o finaliza las tareas del servicio',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _descController,
                    readOnly: widget.estaBloqueado,
                    decoration: InputDecoration(
                      hintText: widget.estaBloqueado 
                        ? 'Edición de tareas bloqueada' 
                        : 'Descripción de la tarea...',
                      border: InputBorder.none,
                      prefixIcon: widget.estaBloqueado ? const Icon(Icons.lock_outline, size: 16) : null,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.estaBloqueado ? Colors.grey : Colors.black
                    ),
                  ),
                  const Divider(),
                  _buildFechaSelector(
                    label: 'Inicio Real:',
                    selectedDate: _fechaInicioNueva,
                    onTap: widget.estaBloqueado ? null : () async {
                      final picked = await _selectDateTime(
                        context,
                        _fechaInicioNueva,
                      );
                      if (picked != null) {
                        setState(() => _fechaInicioNueva = picked);
                      }
                    },
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedTecnicoId,
                            hint: const Text(
                              'Asignar Responsable',
                              style: TextStyle(fontSize: 12),
                            ),
                            isDense: true,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text(
                                  'Sin Responsable',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              ...{
                                for (var s in widget.staffAsignado)
                                  s.staffId: s,
                              }.values.toList().asMap().entries.map((entry) {
                                final index = entry.key;
                                final s = entry.value;
                                final isResponsible = index == 0;

                                return DropdownMenuItem(
                                  value: s.staffId,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        s.fullName,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      if (isResponsible) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange,
                                              width: 0.5,
                                            ),
                                          ),
                                          child: const Text(
                                            'RESP',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            ],
                onChanged: (widget.estaBloqueado)
                                ? null
                                : (val) =>
                                    setState(() => _selectedTecnicoId = val),
                          ),
                        ),
                      ),
                      Material(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: (widget.estaBloqueado || _isAdding) ? null : _agregarOperacion,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            child:
                                _isAdding
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child:
                  provider.operaciones.isEmpty
                      ? const Center(
                        child: Text('No hay operaciones registradas'),
                      )
                      : ListView.builder(
                        itemCount: provider.operaciones.length,
                        itemBuilder: (context, index) {
                          final op = provider.operaciones[index];
                          return _buildModalItem(op, provider, theme);
                        },
                      ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cerrar Ventana'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalItem(
    OperacionModel op,
    OperacionesProvider provider,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap:
                    op.estaFinalizada || widget.estaBloqueado
                        ? null
                        : () => _confirmarFinalizacion(context, op, provider),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        op.estaFinalizada
                            ? Colors.green.withOpacity(0.1)
                            : theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          op.estaFinalizada
                              ? Colors.green.withOpacity(0.3)
                              : theme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        op.estaFinalizada ? Icons.check_circle : Icons.check,
                        color:
                            op.estaFinalizada
                                ? Colors.green
                                : theme.primaryColor,
                        size: 20,
                      ),
                      Text(
                        op.estaFinalizada ? 'Listo' : 'Finalizar',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color:
                              op.estaFinalizada
                                  ? Colors.green
                                  : theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                   onTap:
                       (op.estaFinalizada && !_canEditClosedOps) || widget.estaBloqueado
                           ? null
                           : () => _mostrarDialogoEdicionOperacion(
                            context,
                            op,
                            provider,
                          ),
                  borderRadius: BorderRadius.circular(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              op.descripcion,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration:
                                    op.estaFinalizada
                                        ? TextDecoration.lineThrough
                                        : null,
                              ),
                            ),
                          ),
                           if (!op.estaFinalizada || _canEditClosedOps)
                             Icon(
                               Icons.edit_outlined,
                               size: 14,
                               color: Colors.grey.withOpacity(0.5),
                             ),
                        ],
                      ),
                      if (op.observaciones != null &&
                          op.observaciones!.isNotEmpty)
                        Text(
                          op.observaciones!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if ((!op.estaFinalizada || _canEditClosedOps) &&
                  !op.isMaster) // âœ… PROTECCIÃ“N: No borrar Maestra
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: widget.estaBloqueado
                      ? null
                      : () async {
                          final success = await provider.eliminarOperacion(op.id!);
                          if (!success && mounted) {
                            _handleError(context, provider.lastError ?? 'Error al eliminar');
                          }
                        },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.staffAsignado
                  .where((s) => s.operacionId == op.id)
                  .isNotEmpty)
                _buildSmallBadge(
                  PhosphorIcons.users(),
                  '${widget.staffAsignado.where((s) => s.operacionId == op.id).length}',
                  Colors.orange,
                ),
              if (widget.repuestosAsignados
                  .where((r) => r.operacionId == op.id)
                  .isNotEmpty)
                _buildSmallBadge(
                  PhosphorIcons.package(),
                  '${widget.repuestosAsignados.where((r) => r.operacionId == op.id).length}',
                  Colors.blue,
                ),
              // ✅ Edición de Inicio/Fin directamente desde el modal
              _buildTimeChip(
                label: 'Inicio',
                date:
                    op.fechaInicio != null
                        ? DateTime.parse(
                          op.fechaInicio!.replaceFirst(' ', 'T'),
                        )
                        : null,
                color: Colors.blue,
                onTap:
                    (widget.estaBloqueado || (op.estaFinalizada && !_canEditClosedOps))
                        ? null
                        : () => _editarFechaOperacion(
                              context,
                              op,
                              true,
                              provider,
                            ),
              ),
              _buildTimeChip(
                label: 'Fin',
                date:
                    op.fechaFin != null
                        ? DateTime.parse(
                          op.fechaFin!.replaceFirst(' ', 'T'),
                        )
                        : null,
                color: Colors.green,
                onTap:
                    (widget.estaBloqueado || (op.estaFinalizada && !_canEditClosedOps))
                        ? null
                        : () => _editarFechaOperacion(
                              context,
                              op,
                              false,
                              provider,
                            ),
              ),
              _buildActionLink(
                op.estaFinalizada
                    ? 'Ver Personal'
                    : (widget.estaBloqueado ? 'Personal' : 'Técnico'),
                Colors.orange,
                (widget.estaBloqueado ||
                        (op.estaFinalizada && !_canEditClosedOps))
                    ? null
                    : () => widget.onGestionarStaff?.call(op.id),
                isBlocked: (widget.estaBloqueado ||
                    (op.estaFinalizada && !_canEditClosedOps)),
              ),
              _buildActionLink(
                op.estaFinalizada
                    ? 'Ver Repuestos'
                    : (widget.estaBloqueado ? 'Repuestos' : 'Repuesto'),
                Colors.blue,
                (widget.estaBloqueado ||
                        (op.estaFinalizada && !_canEditClosedOps))
                    ? null
                    : () => widget.onGestionarRepuestos?.call(op.id),
                isBlocked: (widget.estaBloqueado ||
                    (op.estaFinalizada && !_canEditClosedOps)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _agregarOperacion() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty) return;

    setState(() => _isAdding = true);
    final provider = context.read<OperacionesProvider>();
    final success = await provider.agregarOperacion(
      desc,
      actividadId: widget.actividadId,
      tecnicoId: _selectedTecnicoId,
      fechaInicio: _fechaInicioNueva,
    );

    if (mounted) {
      if (success) {
        _descController.clear();
        setState(() {
          _isAdding = false;
          _fechaInicioNueva = DateTime.now();
        });
      } else {
        setState(() => _isAdding = false);
        if (!success) {
          _handleError(context, provider.lastError ?? 'Error al crear operación');
        }
      }
    }
  }

  Future<void> _confirmarFinalizacion(
    BuildContext context,
    OperacionModel op,
    OperacionesProvider provider,
  ) async {
    // Calculamos la fecha mnima permitida (inicio de operacin o creacin)
    DateTime minDateRaw = DateTime(2020);
    if (op.fechaInicio != null) {
      try {
        minDateRaw = DateTime.parse(op.fechaInicio!);
      } catch (_) {}
    } else if (op.createdAt != null) {
      try {
        minDateRaw = DateTime.parse(op.createdAt!);
      } catch (_) {}
    }

    // Convertir a local y al inicio del da para evitar bloqueos por hora
    final localDate = minDateRaw.toLocal();
    final DateTime minDate = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    DateTime selectedDateTime = DateTime.now();
    // Si la fecha actual es anterior a la minDate, ajustar
    if (selectedDateTime.isBefore(minDate)) selectedDateTime = minDate;

    final TextEditingController obsCierreController = TextEditingController();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                title: const Text('Finalizar Operación'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Fecha inicio: ${_formatDate(op.fechaInicio ?? op.createdAt ?? "N/A")}',
                    ),
                    const SizedBox(height: 10),
                    const Text('¿Cuándo se completó?'),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate:
                              selectedDateTime.isBefore(minDate)
                                  ? minDate
                                  : selectedDateTime,
                          firstDate: minDate,
                          lastDate: DateTime.now().add(
                            const Duration(minutes: 1),
                          ),
                        );
                        if (pickedDate != null) {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              selectedDateTime,
                            ),
                          );
                          if (pickedTime != null) {
                            setModalState(
                              () =>
                                  selectedDateTime = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              '${selectedDateTime.day.toString().padLeft(2, '0')}/${selectedDateTime.month.toString().padLeft(2, '0')}/${selectedDateTime.year} ${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      height: 100,
                      width: double.maxFinite,
                      child: TextField(
                        controller: obsCierreController,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones de cierre (opcional)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        minLines: 4,
                        style: const TextStyle(fontSize: 13),
                        scrollPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirmar'),
                  ),
                ],
              );
            },
          ),
    );
    if (confirm == true) {
      final success = await provider.finalizarOperacion(
        op.id!,
        fechaFin: selectedDateTime,
        observaciones: obsCierreController.text.trim(),
      );
      if (!success && mounted) {
        _handleError(context, provider.lastError ?? 'Error al finalizar operación');
      }
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate.replaceFirst(' ', 'T')).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  // ✅ NUEVOS HELPERS PARA TIEMPOS

  Widget _buildFechaSelector({
    required String label,
    required DateTime selectedDate,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Icon(PhosphorIcons.calendar(), size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')} ${selectedDate.hour.toString().padLeft(2, '0')}:${selectedDate.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChip({
    required String label,
    DateTime? date,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$label: ',
                style: TextStyle(
                  fontSize: 9,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                date != null
                    ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                    : 'N/A',
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _selectDateTime(
    BuildContext context,
    DateTime current,
  ) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (pickedTime != null) {
        return DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      }
    }
    return null;
  }

  Future<void> _editarFechaOperacion(
    BuildContext context,
    OperacionModel op,
    bool esInicio,
    OperacionesProvider provider,
  ) async {
    final current =
        esInicio
            ? (op.fechaInicio != null
                ? DateTime.parse(op.fechaInicio!.replaceFirst(' ', 'T'))
                : DateTime.now())
            : (op.fechaFin != null
                ? DateTime.parse(op.fechaFin!.replaceFirst(' ', 'T'))
                : DateTime.now());

    final picked = await _selectDateTime(context, current);
    if (picked != null) {
      // Validación: Fin no puede ser anterior a Inicio
      if (esInicio && op.fechaFin != null) {
        final fin = DateTime.parse(op.fechaFin!.replaceFirst(' ', 'T'));
        if (picked.isAfter(fin)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El inicio no puede ser posterior al fin'),
            ),
          );
          return;
        }
      } else if (!esInicio && op.fechaInicio != null) {
        final inicio = DateTime.parse(op.fechaInicio!.replaceFirst(' ', 'T'));
        if (picked.isBefore(inicio)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El fin no puede ser anterior al inicio'),
            ),
          );
          return;
        }
      }

      final result = await ServicioOperacionesApiService.actualizarOperacion(op.id!, {
        if (esInicio)
          'fecha_inicio': picked.toIso8601String()
        else
          'fecha_fin': picked.toIso8601String(),
      });
      
      if (mounted) {
        if (result['success'] == true) {
          provider.cargarOperaciones(op.servicioId);
        } else {
          _handleError(context, result['message']?.toString() ?? 'Error desconocido');
        }
      }
    }
  }

  Future<void> _mostrarDialogoEdicionOperacion(
    BuildContext context,
    OperacionModel op,
    OperacionesProvider provider,
  ) async {
    final TextEditingController descController = TextEditingController(
      text: op.descripcion,
    );
    final TextEditingController obsController = TextEditingController(
      text: op.observaciones ?? '',
    );

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  PhosphorIcons.pencilSimple(),
                  size: 20,
                  color: Colors.blue,
                ),
                const SizedBox(width: 10),
                const Text('Editar Operación'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción / Nombre',
                    hintText: 'Ej: Alistamiento General',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 1,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: obsController,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    hintText: 'Detalles adicionales...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newDesc = descController.text.trim();
                  if (newDesc.isEmpty) return;

                  final success = await provider.actualizarOperacion(op.id!, {
                    'descripcion': newDesc,
                    'observaciones': obsController.text.trim(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    if (!success) {
                      _handleError(context, provider.lastError ?? 'Error al actualizar la operación');
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }

  Future<void> _loadUserPermissions() async {
    final canEdit = await AuthService.canEditClosedOps();
    if (mounted) {
      setState(() => _canEditClosedOps = canEdit);
    }
  }

  Widget _buildSmallBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionLink(String label, Color color, VoidCallback? onTap, {bool isBlocked = false}) {
    final displayColor = isBlocked ? Colors.grey : color;
    return InkWell(
      onTap: onTap,
      child: Text(
        isBlocked ? label : '+ $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: displayColor,
          decoration: isBlocked ? null : TextDecoration.underline,
        ),
      ),
    );
  }

  void _handleError(BuildContext context, String message) {
    String friendlyMessage = message;
    bool isLegalizado = message.toUpperCase().contains('LEGALIZADO') || 
                       message.toLowerCase().contains('terminal');

    if (isLegalizado) {
      friendlyMessage = 'No se permiten realizar cambios en este servicio porque ya se encuentra en estado LEGALIZADO.\n\n'
          'Si necesitas hacer un ajuste, debes solicitar al área administrativa que retornen el servicio desde Gestión Financiera.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            const Text('Acción Bloqueada', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(friendlyMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
