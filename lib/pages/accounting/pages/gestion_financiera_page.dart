import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../features/auth/data/auth_service.dart';
import '../services/financial_management_service.dart';
import '../models/accounting_models.dart';
import '../widgets/accounting_preview_widget.dart';
import './gestion_periodos_page.dart';
import 'package:infoapp/core/branding/branding_service.dart';
import 'package:intl/intl.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/features/chatbot/data/ai_config_service.dart';

class GestionFinancieraPage extends StatefulWidget {
  const GestionFinancieraPage({super.key});

  @override
  State<GestionFinancieraPage> createState() => _GestionFinancieraPageState();
}

class _GestionFinancieraPageState extends State<GestionFinancieraPage>
    with SingleTickerProviderStateMixin {
  final FinancialManagementService _service =
      FinancialManagementService.instance;
  final BrandingService _brandingService = BrandingService();
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  late TabController _tabController;
  List<FinancialPendingItemModel> _pendingItems = [];
  List<IssuedInvoiceModel> _issuedInvoices = [];
  List<Map<String, dynamic>> _estadosFinancieros = [];
  List<Map<String, dynamic>> _availableTransitions = [];
  final Set<int> _selectedServiceIds = {};
  bool _isLoading = true;
  FinancialPendingItemModel? _selectedItem;
  AccountingEntryPreviewModel? _preview;
  bool _isProcessing = false;
  bool _isFactusConfigured = false;
  bool _showAccountingEntry = true;
  bool _verDetalleCotizacion = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPending();
    _loadIssued();
    _loadEstadosFinancieros();
    _checkConfig();
  }

  Future<void> _loadEstadosFinancieros() async {
    try {
      final estados = await _service.getFinancialStates();
      if (mounted) {
        setState(() {
          _estadosFinancieros = estados;
        });
      }
    } catch (e) {
      print('Error cargando estados financieros: $e');
    }
  }

  Future<void> _checkConfig() async {
    final configured = await _service.checkFacturationConfig();
    if (mounted) {
      setState(() {
        _isFactusConfigured = configured;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    try {
      final items = await _service.getPendingServices();
      setState(() {
        _pendingItems = items;
        _isLoading = false;
      });
    } catch (e) {
      _showError(e.toString());
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadIssued() async {
    try {
      final invoices = await _service.getIssuedInvoices();
      setState(() {
        _issuedInvoices = invoices;
      });
    } catch (e) {
      print('Error al cargar facturas: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _onItemSelected(FinancialPendingItemModel item) async {
    setState(() {
      _selectedItem = item;
      _preview = null;
      _isProcessing = true;
      _availableTransitions = []; // Reset transitions while loading
    });

    try {
      // 1. Cargar previsualización (asiento/items)
      final preview = await _service.previewEntry(item.id);

      // 2. Cargar transiciones permitidas según el workflow
      final transitions = await _service.getAvailableTransitions(servicioId: item.id);

      if (mounted) {
        setState(() {
          _preview = preview;
          _verDetalleCotizacion = preview.verDetalleCotizacion;
          _showAccountingEntry = false;
          _availableTransitions = transitions;
          _isProcessing = false;
        });
      }
    } catch (e) {
      _showError(e.toString());
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showTransitionMenuForInvoice(IssuedInvoiceModel inv) async {
    setState(() => _isProcessing = true);
    try {
      final transitions = await _service.getAvailableTransitions(facturaId: inv.id);
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (transitions.isEmpty) {
        _showError('No hay transiciones disponibles para esta factura.');
        return;
      }

      final nuevoId = await showDialog<int?>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Transiciones: ${inv.fullNumber}'),
            content: SizedBox(
              width: 320,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: transitions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final t = transitions[index];
                  final isActual = t['es_actual'] == true;
                  final color = isActual ? Colors.indigo : Colors.black87;
                  
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isActual ? Icons.check_circle : Icons.arrow_forward_ios,
                      size: 16,
                      color: isActual ? Colors.green : Colors.grey,
                    ),
                    title: Text(
                      t['nombre_estado'] ?? '---',
                      style: TextStyle(
                        fontWeight: isActual ? FontWeight.bold : FontWeight.normal,
                        color: color,
                      ),
                    ),
                    onTap: isActual ? null : () => Navigator.pop(context, int.tryParse(t['id'].toString())),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR'),
              ),
            ],
          );
        }
      );

      if (nuevoId != null) {
        setState(() => _isProcessing = true);
        final success = await _service.changeFinancialState(
          facturaId: inv.id,
          nuevoEstadoId: nuevoId,
        );
        if (success) {
          _loadIssued();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Estado de factura actualizado correctamente.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError(e.toString());
    }
  }

  Future<void> _toggleQuoteDetail(bool value) async {
    if (_selectedItem == null) return;
    setState(() => _verDetalleCotizacion = value);
    try {
      final success = await _service.updateQuoteVisibility(
        _selectedItem!.id,
        value,
      );
      if (!success) {
        // Revertir si falla en el servidor
        setState(() => _verDetalleCotizacion = !value);
        _showError('No se pudo guardar la preferencia de visibilidad');
      }
    } catch (e) {
      setState(() => _verDetalleCotizacion = !value);
      _showError(e.toString());
    }
  }

  Future<void> _showEditSnapshotDialog(
    String campo,
    String label,
    double valorActual, {
    int? inventoryItemId,
    String? infoContexto, // Texto informativo: ej. "2 und × $12,50/und"
  }) async {
    final isSparePart = inventoryItemId != null;
    final controller = TextEditingController(
      text: NumberFormat.decimalPattern('es_CO').format(valorActual),
    );
    final motivoController = TextEditingController();
    bool isSavingLocal = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text('Ajustar $label'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mostrar contexto si es repuesto individual
                  if (infoContexto != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        infoContexto,
                        style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                      ),
                    ),
                  ],
                  TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText:
                          isSparePart
                              ? 'Nuevo Valor Total del Ítem'
                              : 'Nuevo Valor',
                      prefixText: '\$ ',
                      border: const OutlineInputBorder(),
                      helperText:
                          isSparePart
                              ? 'El nuevo total a cobrar por este repuesto'
                              : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: motivoController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Motivo del Ajuste (Obligatorio)',
                      hintText: 'Ej: Descuento comercial acordado...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSavingLocal ? null : () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
                ElevatedButton(
                  onPressed:
                      isSavingLocal
                          ? null
                          : () async {
                            if (motivoController.text.trim().length < 5) {
                              _showError('Debe ingresar un motivo válido.');
                              return;
                            }
                            setDialogState(() => isSavingLocal = true);
                            try {
                              final newValString = controller.text.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              final newVal = double.tryParse(newValString) ?? 0;
                              final success =
                                  isSparePart
                                      ? await _service.updateSparePartValue(
                                        servicioId: _selectedItem!.id,
                                        inventoryItemId: inventoryItemId,
                                        nuevoValorTotal:
                                            newVal, // total del ítem
                                        motivo: motivoController.text.trim(),
                                      )
                                      : await _service.updateSnapshotValue(
                                        servicioId: _selectedItem!.id,
                                        campo: campo,
                                        nuevoValor: newVal,
                                        motivo: motivoController.text.trim(),
                                      );
                              if (success) {
                                Navigator.pop(context);
                                // Refrescar el panel de detalle Y la lista lateral
                                _onItemSelected(_selectedItem!);
                                _loadPending(); // ← refresca subtotal en lista
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Ajuste guardado y auditado.',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              _showError(e.toString());
                            } finally {
                              setDialogState(() => isSavingLocal = false);
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child:
                      isSavingLocal
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text('GUARDAR AJUSTE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAdjustmentHistory() async {
    setState(() => _isProcessing = true);
    try {
      final history = await _service.getSnapshotHistory(_selectedItem!.id);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.history_edu, color: Colors.indigo),
                SizedBox(width: 8),
                Text('Auditoría de Ajustes'),
              ],
            ),
            content:
                history.isEmpty
                    ? const Text('No se han realizado ajustes manuales.')
                    : SizedBox(
                      width: 450,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: history.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final mod = history[index];
                          final fecha = DateFormat(
                            'yyyy-MM-dd HH:mm:ss',
                          ).format(DateTime.parse(mod['fecha']));
                          return ListTile(
                            dense: true,
                            title: Text(
                              mod['campo'],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Valor Antes: ${currencyFormat.format(double.tryParse(mod['valor_anterior'].toString()) ?? 0)}',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                Text(
                                  'Valor Actual: ${currencyFormat.format(double.tryParse(mod['valor_nuevo'].toString()) ?? 0)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Motivo: ${mod['motivo']}',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Modificado por: ${mod['usuario_nombre']} • $fecha',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CERRAR'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _downloadPdf(IssuedInvoiceModel invoice) async {
    final token = await AuthService.getBearerToken();
    final baseUrl = _service.baseUrl.replaceAll('/accounting', '');
    final localPdfUrl =
        '$baseUrl/accounting/generar_factura_pdf.php?id=${invoice.id}&token=$token';

    if (await canLaunchUrl(Uri.parse(localPdfUrl))) {
      await launchUrl(
        Uri.parse(localPdfUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      _showError('No se pudo abrir el PDF');
    }
  }

  Future<void> _devolverAOperaciones() async {
    if (_selectedItem == null) return;
    final motivoController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.undo, color: Colors.orange),
                SizedBox(width: 8),
                Text('Retornar a Operaciones'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Desea retornar este servicio para ajustes técnicos?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: motivoController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de la devolución',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('CONFIRMAR'),
              ),
            ],
          ),
    );

    if (confirm != true) return;
    setState(() => _isProcessing = true);
    try {
      final success = await _service.devolverAOperaciones(
        _selectedItem!.id,
        motivoController.text,
      );
      if (success) {
        _loadPending();
        setState(() {
          _selectedItem = null;
          _preview = null;
        });
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmAccrual() async {
    if (_selectedItem == null) return;
    setState(() => _isProcessing = true);
    try {
      final success = await _service.confirmAccrual(_selectedItem!.id);
      if (success) {
        _loadPending();
        setState(() {
          _selectedItem = null;
          _preview = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Causación registrada con éxito.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _generateInvoice() async {
    if (_selectedServiceIds.isEmpty && _selectedItem != null) {
      _selectedServiceIds.add(_selectedItem!.id);
    }
    if (_selectedServiceIds.isEmpty) return;

    final firstItem = _pendingItems.firstWhere(
      (it) => _selectedServiceIds.contains(it.id),
      orElse: () => _selectedItem!,
    );

    String metodoPago = 'CREDITO';
    final observacionesController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Generar Factura Comercial'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Se generará factura para ${_selectedServiceIds.length} servicios de: ${firstItem.clienteNombre}',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: metodoPago,
                    decoration: const InputDecoration(labelText: 'Método'),
                    items: const [
                      DropdownMenuItem(
                        value: 'CONTADO',
                        child: Text('Contado'),
                      ),
                      DropdownMenuItem(
                        value: 'CREDITO',
                        child: Text('Crédito'),
                      ),
                    ],
                    onChanged: (v) => metodoPago = v!,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: observacionesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('GENERAR'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final res = await _service.createInvoice(
        clienteId: firstItem.clienteId,
        serviciosIds: _selectedServiceIds.toList(),
        metodoPago: metodoPago,
        prefijo: 'SETP',
        observaciones: observacionesController.text,
      );
      if (res['success']) {
        _loadPending();
        _loadIssued();
        _selectedServiceIds.clear();
        _selectedItem = null;
        _preview = null;
        _tabController.animateTo(1);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _analizarConIA({bool refresh = false}) async {
    if (_selectedItem == null) return;
    setState(() => _isProcessing = true);

    try {
      final result = await _service.analizarCotizacionIA(
        _selectedItem!.id,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildAIResultSheet(result),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError(e.toString());
      }
    }
  }

  Widget _buildAIResultSheet(Map<String, dynamic> result) {
    final bool isPersisted = result['persisted'] ?? false;
    final String fecha = result['fecha'] ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome, color: Colors.purple[700]),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auditores IA Predictive',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1C1E),
                        ),
                      ),
                      Text(
                        'Análisis de Integridad y Rentabilidad',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (isPersisted)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.purple),
                    onPressed: () {
                      Navigator.pop(context);
                      _analizarConIA(refresh: true);
                    },
                    tooltip: 'Nuevo análisis',
                  ),
              ],
            ),
          ),
          if (isPersisted)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'Análisis guardado del $fecha',
                    style: TextStyle(fontSize: 11, color: Colors.amber[900]),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hub, size: 18, color: Colors.indigo),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Fuente: ${result['fuente']}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    result['analisis'],
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF44474E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildAIActionButtons(result['analisis']),
        ],
      ),
    );
  }

  Widget _buildAIActionButtons(String content) {
    bool hasRisk =
        content.toLowerCase().contains('riesgo') ||
        content.toLowerCase().contains('alerta');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('CERRAR'),
            ),
          ),
          const SizedBox(width: 16),
          if (hasRisk)
            Expanded(
              child: ElevatedButton(
                onPressed: () => _handleExceptionApproval(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'APROBAR EXCEPCIÓN',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ENTENDIDO',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleExceptionApproval() async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Justificación de Excepción'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ej: Diferencia de MO aprobada por cliente...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('VALIDAR EXCEPCIÓN'),
              ),
            ],
          ),
    );

    if (confirm == true && controller.text.isNotEmpty) {
      Navigator.pop(context); // Cerrar bottom sheet
      setState(() => _isProcessing = true);
      try {
        await _service.registrarAuditoria(
          _selectedItem!.id,
          comentario: '[EXCEPCIÓN IA] ${controller.text}',
          esExcepcion: true,
        );
        _onItemSelected(_selectedItem!); // Refrescar vista
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excepción registrada con éxito.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        _showError(e.toString());
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: TabBar(
          controller: _tabController,
          labelColor: _brandingService.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _brandingService.primaryColor,
          indicatorWeight: 3,
          isScrollable: true,
          tabs: const [
            Tab(text: 'DASHBOARD COMERCIAL'),
            Tab(text: 'HISTÓRICO LEGAL'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GestionPeriodosPage(),
                    ),
                  ).then((_) => _loadPending()),
              icon: const Icon(Icons.calendar_month, size: 18),
              label: const Text(
                'GESTIÓN PERIODOS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.indigo.shade800,
                side: BorderSide(color: Colors.indigo.shade800, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPendingView(), _buildInvoicedView()],
      ),
    );
  }

  Widget _buildPendingView() {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildDashboard()),
        const VerticalDivider(width: 1),
        Expanded(flex: 3, child: _buildDetailArea()),
      ],
    );
  }

  Widget _buildInvoicedView() {
    return _buildInvoicedList();
  }

  Widget _buildDashboard() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Servicios Pendientes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child:
              _pendingItems.isEmpty
                  ? const Center(child: Text('No hay servicios pendientes'))
                  : ListView.builder(
                    itemCount: _pendingItems.length,
                    itemBuilder: (context, index) {
                      final item = _pendingItems[index];
                      final isSelected = _selectedItem?.id == item.id;

                      return Card(
                        elevation: isSelected ? 4 : 1,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color:
                                isSelected
                                    ? _brandingService.primaryColor
                                    : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        color: isSelected ? Colors.grey[50] : Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Checkbox(
                            value: _selectedServiceIds.contains(item.id),
                            activeColor: _brandingService.primaryColor,
                            onChanged:
                                item.estadoComercial != 'CAUSADO'
                                    ? null
                                    : (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedServiceIds.add(item.id);
                                        } else {
                                          _selectedServiceIds.remove(item.id);
                                        }
                                      });
                                    },
                          ),
                          title: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'OT: ${item.numeroOrden}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              _buildStatusBadge(item.estadoComercial),
                              _buildFinancialBadgeForValues(item.estadoFinancieroNombre, item.estadoFinancieroColor),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 4),
                                child: Text(
                                  item.clienteNombre.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              if (item.estadoFinFechaInicio != null)
                                _buildTimerWidget(item.estadoFinFechaInicio!),
                            ],
                          ),
                          trailing: Text(
                            currencyFormat.format(item.valorSnapshot),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green[700],
                            ),
                          ),
                          onTap: () => _onItemSelected(item),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildInvoicedList() {
    return ListView.builder(
      itemCount: _issuedInvoices.length,
      itemBuilder: (context, index) {
        final inv = _issuedInvoices[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const Icon(Icons.description, color: Colors.green),
            title: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  inv.fullNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _buildFinancialBadgeForValues(inv.estadoFinancieroNombre, inv.estadoFinancieroColor),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  inv.clienteNombre.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (inv.servicios.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(Icons.hub_outlined, size: 10, color: Colors.blueGrey[400]),
                      ...inv.servicios.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blueGrey[100]!, width: 0.5),
                        ),
                        child: Text(
                          'OT: $s',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.blueGrey[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ],
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.indigo),
                  tooltip: 'Cambiar Estado Financiero',
                  onPressed: () => _showTransitionMenuForInvoice(inv),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  onPressed: () => _downloadPdf(inv),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailArea() {
    if (_selectedItem == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Selecciona una OT para previsualizar',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey[50], // Fondo ligeramente gris para resaltar tarjetas
      child: Column(
        children: [
          Expanded(
            child:
                _preview == null || _isProcessing
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildViewToggle(),
                          const SizedBox(height: 16),
                          _buildFinancialStateSelector(),
                          const SizedBox(height: 24),
                          _showAccountingEntry
                              ? AccountingPreviewWidget(preview: _preview!)
                              : _buildCommercialQuoteView(),
                        ],
                      ),
                    ),
          ),
          if (_preview != null && !_isProcessing) ...[
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  if (_showAccountingEntry)
                    _buildConfirmButton()
                  else if (_selectedItem?.estadoComercial == 'CAUSADO')
                    _buildFacturarButton()
                  else
                    _buildDevolverButton(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    String label = status;
    switch (status) {
      case 'NO_FACTURADO':
      case 'PENDIENTE':
        color = Colors.orange;
        label = 'POR CAUSAR';
        break;
      case 'CAUSADO':
        color = Colors.blue;
        label = 'LISTO P/ FACTURAR';
        break;
      case 'FACTURADO':
        color = Colors.green;
        label = 'FACTURADO';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFinancialBadgeForValues(String? nombre, String? color) {
    if (nombre == null || nombre.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Parse color format like '#FF9C27B0' or '#9C27B0'
    Color badgeColor = Colors.grey;
    if (color != null && color.isNotEmpty) {
      try {
        String hexString = color.replaceAll('#', '');
        if (hexString.length == 6) {
          hexString = 'FF$hexString';
        }
        badgeColor = Color(int.parse(hexString, radix: 16));
      } catch (e) {
        // Fallback
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 0.5),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet, size: 10, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            nombre,
            style: TextStyle(
              fontSize: 10,
              color: badgeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerWidget(DateTime startDate) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 30)), // Update roughly twice a minute
      builder: (context, snapshot) {
        final duration = DateTime.now().difference(startDate);
        
        final days = duration.inDays;
        final hours = duration.inHours % 24;
        final minutes = duration.inMinutes % 60;
        
        String timeStr = '';
        Color timeColor = Colors.grey[600]!;

        if (days > 0) {
          timeStr = '${days}d ${hours}h';
          if (days >= 3) timeColor = Colors.red[700]!;
          else if (days >= 1) timeColor = Colors.orange[700]!;
        } else if (hours > 0) {
          timeStr = '${hours}h ${minutes}m';
        } else {
          timeStr = '${minutes}m';
          timeColor = Colors.green[700]!;
        }

        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.timer_outlined, size: 12, color: timeColor),
            const SizedBox(width: 4),
            Text(
              'Tiempo en estado: $timeStr',
              style: TextStyle(
                fontSize: 11,
                color: timeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmButton() {
    final canConfirm =
        PermissionStore.instance.can('gestion_financiera', 'actualizar') ||
        PermissionStore.instance.isAdmin;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_isProcessing || !canConfirm) ? null : _confirmAccrual,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
        label: const Text(
          'CONFIRMAR CAUSACIÓN DE ESTE SERVICIO',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildDevolverButton() {
    final canDevolver =
        PermissionStore.instance.can('gestion_financiera', 'devolver') ||
        PermissionStore.instance.isAdmin;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed:
            (_isProcessing || !canDevolver) ? null : _devolverAOperaciones,
        icon: const Icon(Icons.settings_backup_restore, color: Colors.orange),
        label: const Text(
          'RETORNAR A OPERACIONES PARA AJUSTES',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.orange, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildFacturarButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _generateInvoice,
        icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
        label: const Text(
          'EMITIR FACTURA',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadCotizacionButton() {
    final canExportar =
        PermissionStore.instance.can('gestion_financiera', 'exportar') ||
        PermissionStore.instance.isAdmin;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed:
            canExportar
                ? () => _service
                    .downloadCotizacion(_selectedItem!.id)
                    .catchError((e) => _showError(e.toString()))
                : null,
        icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
        label: const Text(
          'DESCARGAR COTIZACIÓN / PRO-FORMA',
          style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blueGrey,
          side: BorderSide(color: Colors.blueGrey.withOpacity(0.3), width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _showAccountingEntry
                  ? 'Previsualización de Asiento'
                  : 'Detalle de Cotización comercial',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (_showAccountingEntry) ...[
              const SizedBox(height: 4),
              Text(
                'Ref: PREV-OT-${_selectedItem!.id}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        Row(
          children: [
            if (_showAccountingEntry) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Periodo Abierto',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            TextButton.icon(
              onPressed:
                  () => setState(
                    () => _showAccountingEntry = !_showAccountingEntry,
                  ),
              icon: Icon(
                _showAccountingEntry ? Icons.receipt : Icons.grid_view,
                color: _brandingService.primaryColor,
              ),
              label: Text(
                _showAccountingEntry ? 'VER COTIZACIÓN' : 'VER ASIENTO',
                style: TextStyle(
                  color: _brandingService.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommercialQuoteView() {
    final bool canAnalyze = _selectedItem?.estadoComercial != 'CAUSADO';
    return Column(
      children: [
        AnimatedBuilder(
          animation: AiConfigService(),
          builder: (context, _) {
            final bool isAiConfigured = AiConfigService().isAiEnabled;
            return Row(
              children: [
                Expanded(child: _buildDownloadCotizacionButton()),
                if (canAnalyze && isAiConfigured) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _analizarConIA,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text(
                        'Analizar con IA',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),

        const SizedBox(height: 24),
        Card(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    // --- PANEL DE AUDITORÍA REMOVIDO ---
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () => _toggleQuoteDetail(!_verDetalleCotizacion),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _verDetalleCotizacion,
                                onChanged: (v) => _toggleQuoteDetail(v ?? true),
                                activeColor: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Ver detalle en cotización',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_verDetalleCotizacion) ...[
                      // Agrupar items por código para evitar duplicados cuando
                      // múltiples reglas de causación mapean al mismo código de cuenta
                      ..._buildDeduplicatedQuoteRows(),
                    ] else
                      _buildQuoteRow(
                        'SERVICIO INTEGRAL DE MANTENIMIENTO: ${_selectedItem!.numeroOrden}',
                        _preview!.subtotal,
                        icon: Icons.miscellaneous_services_outlined,
                      ),
                    const SizedBox(height: 24),
                    const Divider(thickness: 1.2),
                    const SizedBox(height: 24),
                    _buildQuoteRow(
                      'Subtotal',
                      _preview!.subtotal,
                      isBold: true,
                      fontSize: 16,
                    ),
                    _buildQuoteRow(
                      'IVA (19%)',
                      _preview!.impuesto,
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 24),
                    _buildQuoteRow(
                      'TOTAL COTIZACIÓN',
                      _preview!.subtotal + _preview!.impuesto,
                      isBold: true,
                      fontSize: 24,
                      color: Colors.green[800],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: _showAdjustmentHistory,
                  icon: const Icon(Icons.history_edu, color: Colors.indigo),
                  tooltip: 'Ver Auditoría',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Agrupa los detalles del asiento que empiezan en '41' para evitar mostrar
  /// filas duplicadas cuando múltiples reglas de [fin_config_causacion] generan
  /// entradas con el mismo código y nombre.
  List<Widget> _buildDeduplicatedQuoteRows() {
    // 1. Filtrar sólo cuentas de ingreso (código empieza en '41')
    final Items = _preview!.detalles.where((d) => d.codigo.startsWith('41'));

    // 2. Agrupar por (codigo + nombre), sumando valores
    final Map<String, _QuoteItem> grouped = {};
    for (final d in Items) {
      final key = '${d.codigo}|${d.nombre}';
      if (grouped.containsKey(key)) {
        grouped[key] = _QuoteItem(
          codigo: d.codigo,
          nombre: d.nombre,
          valor: grouped[key]!.valor + d.valor,
          inventoryItemId: grouped[key]!.inventoryItemId ?? d.inventoryItemId,
        );
      } else {
        grouped[key] = _QuoteItem(
          codigo: d.codigo,
          nombre: d.nombre,
          valor: d.valor,
          inventoryItemId: d.inventoryItemId,
        );
      }
    }

    // 3. Renderizar una fila por ítem único
    return grouped.values.map((item) {
      return _buildQuoteRow(
        item.nombre,
        item.valor,
        icon:
            item.codigo == '4135'
                ? Icons.settings_input_component_outlined
                : Icons.engineering_outlined,
        fieldKey: item.codigo == '4135' ? 'REPUESTOS' : 'MANO_OBRA',
        inventoryItemId: item.inventoryItemId,
      );
    }).toList();
  }

  Widget _buildQuoteRow(
    String label,
    double value, {
    bool isBold = false,
    double fontSize = 14,
    Color? color,
    IconData? icon,
    String? fieldKey,
    int? inventoryItemId,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: Colors.grey[400]),
            const SizedBox(width: 20),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.grey[900],
            ),
          ),
          if (fieldKey != null && _selectedItem?.estadoComercial != 'CAUSADO')
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                icon: const Icon(
                  Icons.edit_note,
                  size: 24,
                  color: Colors.indigo,
                ),
                onPressed:
                    () => _showEditSnapshotDialog(
                      fieldKey,
                      label,
                      value,
                      inventoryItemId: inventoryItemId,
                      infoContexto:
                          inventoryItemId != null
                              ? 'Editando el valor TOTAL de este repuesto.\n'
                                  'El precio unitario se ajustará automáticamente\n'
                                  'según la cantidad registrada en el servicio.'
                              : null,
                    ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Editar valor (Auditado)',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFinancialStateSelector() {
    if (_selectedItem == null) return const SizedBox.shrink();

    // Usar transiciones disponibles o fallback a la lista general si aún no cargan
    final options = _availableTransitions.isNotEmpty 
        ? _availableTransitions 
        : _estadosFinancieros;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: Colors.indigo),
              SizedBox(width: 12),
              Text(
                'Fase Financiera:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
            ],
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedItem!.estadoFinancieroId,
                hint: const Text('Gestionar estado...'),
                isExpanded: true,
                items: options.map((est) {
                  final isActual = est['es_actual'] == true;
                  return DropdownMenuItem<int>(
                    value: int.tryParse(est['id'].toString()),
                    child: Text(
                      est['nombre_estado'] ?? 'Desconocido',
                      style: TextStyle(
                        fontWeight: isActual ? FontWeight.bold : FontWeight.normal,
                        color: isActual ? Colors.indigo : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (nuevoId) async {
                  if (nuevoId == null || nuevoId == _selectedItem!.estadoFinancieroId) return;
                  
                  setState(() => _isProcessing = true);
                  try {
                    final success = await _service.changeFinancialState(
                      servicioId: _selectedItem!.id,
                      nuevoEstadoId: nuevoId,
                    );
                    if (success) {
                      await _loadPending();
                      // Refrescar el ítem seleccionado y sus transiciones
                      final updatedItem = _pendingItems.firstWhere(
                        (i) => i.id == _selectedItem!.id,
                        orElse: () => _selectedItem!,
                      );
                      await _onItemSelected(updatedItem);
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fase financiera actualizada correctamente.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    _showError(e.toString());
                  } finally {
                    setState(() => _isProcessing = false);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat.decimalPattern('es_CO');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    // Eliminar todo lo que no sea dígito
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    double value = double.parse(newText);
    String formattedText = _formatter.format(value);

    return newValue.copyWith(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

/// Modelo interno para agrupar items de la cotizacion antes de renderizar.
class _QuoteItem {
  final String codigo;
  final String nombre;
  final double valor;
  final int? inventoryItemId;
  const _QuoteItem({
    required this.codigo,
    required this.nombre,
    required this.valor,
    this.inventoryItemId,
  });
}
