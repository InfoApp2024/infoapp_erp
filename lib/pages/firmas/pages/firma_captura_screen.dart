import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../controllers/firmas_controller.dart';
import '../widgets/signature_pad_widget.dart';
import '../../servicios/models/servicio_model.dart';
import 'package:infoapp/features/auth/data/admin_user_service.dart';
import '../../servicios/models/funcionario_model.dart';
import '../widgets/seleccionar_staff_dialog.dart';
import '../widgets/seleccionar_funcionario_dialog.dart';
import '../models/firma_model.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import 'package:infoapp/pages/servicios/services/servicios_sync_queue.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirmaCapturaScreen extends StatefulWidget {
  final ServicioModel? servicio;

  const FirmaCapturaScreen({super.key, this.servicio});

  @override
  State<FirmaCapturaScreen> createState() => _FirmaCapturaScreenState();
}

class _FirmaCapturaScreenState extends State<FirmaCapturaScreen> {
  final _notaEntregaController = TextEditingController();
  final _notaRecepcionController = TextEditingController();

  ServicioModel? _servicioSeleccionado;
  AdminUser? _staffSeleccionado;
  FuncionarioModel? _funcionarioSeleccionado;
  bool _soloLectura = false;
  FirmaModel? _firmaExistente;

  @override
  void initState() {
    super.initState();
    _servicioSeleccionado = widget.servicio;

    // Si viene un servicio, establecerlo en el controller
    if (widget.servicio != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = context.read<FirmasController>();
        final servicioId = widget.servicio?.id;
        if (servicioId != null) {
          controller.setServicioSeleccionado(servicioId);
          _cargarFirmaSiExiste(servicioId);
        }
      });
    }
  }

  Widget _buildSignaturePreview({
    required String label,
    required String? dataUrl,
    required Color color,
  }) {
    Uint8List? imageBytes;
    try {
      if (dataUrl != null && dataUrl.trim().isNotEmpty) {
        // Limpia espacios/saltos de línea y elimina prefijo dataURL si existe
        final cleaned = dataUrl
            .trim()
            .replaceAll('\n', '')
            .replaceAll('\r', '');
        final withoutPrefix = cleaned.replaceFirst(
          RegExp(r'^data:image/[^;]+;base64,'),
          '',
        );
        // Normaliza padding y decodifica de forma robusta
        final normalized = base64.normalize(withoutPrefix);
        imageBytes = base64Decode(normalized);
      }
    } catch (e) {
      debugPrint('Error decodificando firma: $e');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100,
          ),
          alignment: Alignment.center,
          child:
              imageBytes != null
                  ? Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  )
                  : const Text('Sin firma registrada'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _notaEntregaController.dispose();
    _notaRecepcionController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarServicio() async {
    // Aquí implementarías tu modal de selección de servicios
    // Similar a como lo haces en el módulo de servicios

    // Ejemplo básico:
    // final servicio = await showDialog<ServicioModel>(
    //   context: context,
    //   builder: (context) => SeleccionarServicioModal(),
    // );

    // if (servicio != null) {
    //   setState(() {
    //     _servicioSeleccionado = servicio;
    //   });
    //   context.read<FirmasController>().setServicioSeleccionado(servicio.id);
    // }
  }

  Future<void> _seleccionarStaff() async {
    final usuario = await showDialog<AdminUser>(
      context: context,
      builder: (context) => const SeleccionarStaffDialog(),
    );

    if (usuario != null) {
      setState(() => _staffSeleccionado = usuario);
      context.read<FirmasController>().setStaffSeleccionado(usuario.id);
    }
  }

  Future<void> _seleccionarFuncionario() async {
    final funcionario = await showDialog<FuncionarioModel>(
      context: context,
      builder:
          (context) => SeleccionarFuncionarioDialog(
            clienteId: _servicioSeleccionado?.clienteId,
          ),
    );

    if (funcionario != null) {
      setState(() => _funcionarioSeleccionado = funcionario);
      context.read<FirmasController>().setFuncionarioSeleccionado(
        funcionario.id,
      );
    }
  }

  Future<void> _guardarFirma() async {
    final controller = context.read<FirmasController>();

    // Actualizar notas en el controller
    controller.setNotaEntrega(
      _notaEntregaController.text.isEmpty ? null : _notaEntregaController.text,
    );
    controller.setNotaRecepcion(
      _notaRecepcionController.text.isEmpty
          ? null
          : _notaRecepcionController.text,
    );

    // Confirmación antes de guardar
    final confirmado = await _confirmarGuardado();
    if (!confirmado) return;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final errores = controller.validarFormulario();
    if (errores.isNotEmpty) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errores.values.first),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Crear firma
    final online = await ConnectivityService.instance.checkNow();

    if (!online) {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('En la web no se permite trabajar sin conexión.'),
            backgroundColor: Colors.red,
          ),
        );
        if (mounted) Navigator.pop(context);
        return;
      }

      final servicioId = controller.servicioSeleccionado!;
      final staffId = controller.staffSeleccionado!;
      final funcionarioId = controller.funcionarioSeleccionado!;
      final firmaStaff = controller.firmaStaffBase64!;
      final firmaFuncionario = controller.firmaFuncionarioBase64!;
      final notaEntrega = controller.notaEntrega;
      final notaRecepcion = controller.notaRecepcion;

      await ServiciosSyncQueue.enqueueCrearFirma(
        servicioId: servicioId,
        staffEntregaId: staffId,
        funcionarioRecibeId: funcionarioId,
        firmaStaffBase64: firmaStaff,
        firmaFuncionarioBase64: firmaFuncionario,
        notaEntrega: notaEntrega,
        notaRecepcion: notaRecepcion,
      );

      if (mounted) Navigator.pop(context);
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => AlertDialog(
                content: Row(
                  children: [
                    Icon(PhosphorIcons.checkCircle(), color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sin conexión. La firma se guardó localmente y se sincronizará al reconectar.',
                      ),
                    ),
                  ],
                ),
              ),
        );
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.pop(context, true);
        });
      }
      return;
    }

    final result = await controller.crearFirma();

    // Cerrar loading
    if (mounted) Navigator.pop(context);

    // Mostrar resultado
    if (mounted) {
      if (result['success'] == true) {
        // Mostrar confirmación clara de guardado (no bloqueante)
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => AlertDialog(
                content: Row(
                  children: [
                    Icon(PhosphorIcons.checkCircle(), color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(child: Text('Firma guardada exitosamente')),
                  ],
                ),
              ),
        );
        // Cerrar el diálogo y regresar automáticamente
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          // Cerrar el diálogo de éxito
          Navigator.of(context, rootNavigator: true).pop();
          // Volver a la vista anterior (Servicios)
          Navigator.pop(context, true);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Error al crear firma'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cargarFirmaSiExiste(int servicioId) async {
    final controller = context.read<FirmasController>();
    // 🔎 Debug: log de carga
    // ignore: avoid_print
    print(
      '[FirmaCapturaScreen] Cargando firmas existentes para servicioId=$servicioId',
    );
    final firmas = await controller.obtenerFirmasPorServicio(servicioId);
    // ignore: avoid_print
    print('[FirmaCapturaScreen] Firmas encontradas: ${firmas.length}');
    if (firmas.isNotEmpty) {
      setState(() {
        _soloLectura = true;
        _firmaExistente = firmas.first;
        _notaEntregaController.text = _firmaExistente?.notaEntrega ?? '';
        _notaRecepcionController.text = _firmaExistente?.notaRecepcion ?? '';
      });
      // ignore: avoid_print
      print(
        '[FirmaCapturaScreen] Activado modo lectura con firma ID=${_firmaExistente?.id}',
      );
    }
  }

  Future<bool> _confirmarGuardado() async {
    final continuar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar firma'),
            content: const Text(
              'Una vez firmado no se podrán realizar cambios. ¿Desea continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continuar'),
              ),
            ],
          ),
    );
    return continuar == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrega de Vehículo'),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.question()),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Ayuda'),
                      content: const Text(
                        'Complete todos los campos obligatorios y capture ambas firmas para registrar la entrega del vehículo.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Entendido'),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: Consumer<FirmasController>(
        builder: (context, controller, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información del servicio
                _buildServicioSection(),

                // Aviso: servicio ya firmado
                if (_soloLectura) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9), // verde claro
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF81C784)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          PhosphorIcons.checkCircle(),
                          color: Color(0xFF2E7D32),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Este servicio ya fue firmado. La información se muestra en modo lectura.',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // Sección: Quien entrega (Staff)
                _buildStaffSection(controller),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // Sección: Quien recibe (Funcionario)
                _buildFuncionarioSection(controller),

                const SizedBox(height: 32),

                // Botones de acción
                _buildAcciones(controller),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildServicioSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información del Servicio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (_servicioSeleccionado != null) ...[
              _buildInfoRow(
                'N° Servicio',
                '#${_servicioSeleccionado!.oServicio.toString().padLeft(4, '0')}',
              ),
              _buildInfoRow(
                'Orden Cliente',
                _servicioSeleccionado!.ordenCliente ?? 'N/A',
              ),
              _buildInfoRow(
                'Tipo Mantenimiento',
                _servicioSeleccionado!.tipoMantenimiento ?? 'N/A',
              ),
              _buildInfoRow('Placa', _servicioSeleccionado!.placa ?? 'N/A'),
            ] else
              ElevatedButton.icon(
                onPressed: _seleccionarServicio,
                icon: Icon(PhosphorIcons.magnifyingGlass()),
                label: const Text('Seleccionar Servicio'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffSection(FirmasController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quien Entrega (Personal de la Empresa)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Selección de staff
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(PhosphorIcons.user())),
            title: Text(
              _soloLectura
                  ? (_firmaExistente?.staffNombre ?? 'Personal')
                  : (_staffSeleccionado != null
                      ? (_staffSeleccionado!.usuario.trim().isNotEmpty
                          ? _staffSeleccionado!.usuario
                          : (_staffSeleccionado!.nombreCompleto ?? ''))
                      : 'Seleccionar personal'),
            ),
            subtitle:
                _soloLectura
                    ? Text(_firmaExistente?.staffEmail ?? '')
                    : (_staffSeleccionado != null
                        ? Text(_staffSeleccionado!.correo ?? '')
                        : null),
            trailing: Icon(PhosphorIcons.caretRight()),
            onTap: _soloLectura ? null : _seleccionarStaff,
          ),
        ),

        const SizedBox(height: 16),

        // Firma del staff
        _soloLectura
            ? _buildSignaturePreview(
              label: 'Firma del Personal',
              dataUrl: _firmaExistente?.firmaStaffBase64,
              color: Colors.blue,
            )
            : SignaturePadWidget(
              label: 'Firma del Personal',
              onSignatureChanged: (base64) {
                controller.setFirmaStaff(base64);
              },
              penColor: Colors.blue,
            ),

        const SizedBox(height: 16),

        // Nota del staff
        TextField(
          controller: _notaEntregaController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Comentarios de entrega (opcional)',
            hintText: 'Ej: Vehículo entregado en buenas condiciones',
            border: OutlineInputBorder(),
          ),
          enabled: !_soloLectura,
        ),
      ],
    );
  }

  Widget _buildFuncionarioSection(FirmasController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quien Recibe (Cliente/Funcionario)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Selección de funcionario
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(PhosphorIcons.buildings())),
            title: Text(
              _soloLectura
                  ? (_firmaExistente?.funcionarioNombre ?? 'Funcionario')
                  : (_funcionarioSeleccionado != null
                      ? _funcionarioSeleccionado!.nombre
                      : 'Seleccionar funcionario'),
            ),
            subtitle:
                _soloLectura
                    ? Text(
                      [
                            _firmaExistente?.funcionarioCargo,
                            _firmaExistente?.funcionarioEmpresa,
                          ]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                    )
                    : (_funcionarioSeleccionado != null
                        ? Text(
                          [
                                _funcionarioSeleccionado!.cargo,
                                _funcionarioSeleccionado!.empresa,
                              ]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                        )
                        : null),
            trailing: Icon(PhosphorIcons.caretRight()),
            onTap: _soloLectura ? null : _seleccionarFuncionario,
          ),
        ),

        const SizedBox(height: 16),

        // Firma del funcionario
        _soloLectura
            ? _buildSignaturePreview(
              label: 'Firma del Funcionario',
              dataUrl: _firmaExistente?.firmaFuncionarioBase64,
              color: Colors.green,
            )
            : SignaturePadWidget(
              label: 'Firma del Funcionario',
              onSignatureChanged: (base64) {
                controller.setFirmaFuncionario(base64);
              },
              penColor: Colors.green,
            ),

        const SizedBox(height: 16),

        // Nota del funcionario
        TextField(
          controller: _notaRecepcionController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Comentarios de recepción (opcional)',
            hintText: 'Ej: Recibido conforme',
            border: OutlineInputBorder(),
          ),
          enabled: !_soloLectura,
        ),
      ],
    );
  }

  Widget _buildAcciones(FirmasController controller) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              controller.limpiarFormulario();
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed:
                (_soloLectura || controller.isLoading) ? null : _guardarFirma,
            child:
                controller.isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Guardar Firma'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
