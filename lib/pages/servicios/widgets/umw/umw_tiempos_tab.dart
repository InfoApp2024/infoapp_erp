import 'dart:async';
import 'package:flutter/material.dart';
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:infoapp/pages/servicios/models/service_time_log_model.dart';
import 'package:infoapp/pages/servicios/services/servicios_api_service.dart';
import 'package:infoapp/pages/servicios/controllers/branding_controller.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

class UmwTiemposTab extends StatefulWidget {
  final ServicioModel servicio;

  const UmwTiemposTab({super.key, required this.servicio});

  @override
  State<UmwTiemposTab> createState() => _UmwTiemposTabState();
}

class _UmwTiemposTabState extends State<UmwTiemposTab> {
  List<ServiceTimeLogModel> _logs = [];
  bool _isLoading = true;
  String? _error;
  Timer? _realTimeTimer;
  Duration _totalAcumulado = Duration.zero;

  @override
  void initState() {
    super.initState();
    _cargarLogs();
    // Actualizar el tiempo real cada minuto
    _realTimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _realTimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarLogs() async {
    if (!mounted) return;

    final servicioId = widget.servicio.id;
    if (servicioId == null) {
      if (mounted) {
        setState(() {
          _error = 'El servicio no tiene un ID vlido';
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ServiciosApiService.obtenerLogsTiempo(servicioId);
      if (res.isSuccess) {
        if (mounted) {
          setState(() {
            _logs = res.data ?? [];
            _calcularTotalAcumulado();
            _isLoading = false;
          });
        }
      } else {
        throw Exception(res.error ?? 'Error cargando tiempos');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _calcularTotalAcumulado() {
    int totalSegundos = 0;
    for (var log in _logs) {
      totalSegundos += log.durationSeconds;
    }
    _totalAcumulado = Duration(seconds: totalSegundos);
  }

  Duration _getTiempoEnEstadoActual() {
    if (_logs.isEmpty) return Duration.zero;

    // El último log marca la entrada al estado actual
    final ultimoLog = _logs.last;
    try {
      String ts = ultimoLog.timestamp;
      if (!ts.contains('T')) {
        ts = ts.replaceAll(' ', 'T');
      }
      final entrada = DateTime.parse(ts);
      return DateTime.now().difference(entrada);
    } catch (_) {
      return Duration.zero;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h ${duration.inMinutes % 60}m';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = context.watch<BrandingController>().branding;
    final brandColor = branding?.primaryColor ?? Theme.of(context).primaryColor;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.warningCircle(), size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'No se pudieron cargar los tiempos',
              style: TextStyle(color: Colors.grey[700]),
            ),
            TextButton(onPressed: _cargarLogs, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final tiempoActual = _getTiempoEnEstadoActual();
    final totalConActual = _totalAcumulado + tiempoActual;

    return Column(
      children: [
        // Tarjeta de Resumen Actual (Toque Senior)
        _buildTotalCard(brandColor, totalConActual, tiempoActual),

        const Divider(height: 1),

        Expanded(
          child:
              _logs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      // Invertir orden para que el más reciente esté arriba
                      final log = _logs[_logs.length - 1 - index];
                      return _buildTimelineItem(
                        context,
                        log,
                        brandColor,
                        index == 0,
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildTotalCard(Color brandColor, Duration total, Duration actual) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brandColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandColor.withOpacity(0.2), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.timer(), color: brandColor),
              const SizedBox(width: 8),
              Text(
                'TIEMPO TOTAL DE GESTIÓN',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: brandColor,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatDuration(total),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Estado actual: ${widget.servicio.estadoNombre} (hace ${_formatDuration(actual)})',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    ServiceTimeLogModel log,
    Color brandColor,
    bool isLast,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lnea de tiempo
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: brandColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: brandColor.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: brandColor.withOpacity(0.2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Contenido de la transicin
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.arrowsLeftRight(),
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.fromStatusName != null
                              ? '${log.fromStatusName} \u2192 ${log.toStatusName}'
                              : 'Inicio del Servicio (${log.toStatusName})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Duración: ${log.formattedDuration}',
                    style: TextStyle(
                      color: brandColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(PhosphorIcons.user(), size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        log.userName ?? 'N/A',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        PhosphorIcons.calendar(),
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        log.formattedDateTime,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.clockCounterClockwise(),
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Sin registros de tiempo todavía',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
