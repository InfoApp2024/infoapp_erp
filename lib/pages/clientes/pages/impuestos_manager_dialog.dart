import 'package:flutter/material.dart';
import 'package:infoapp/pages/clientes/models/impuesto_model.dart';
import 'package:infoapp/pages/clientes/models/ciudad_model.dart';
import 'package:infoapp/pages/clientes/models/tarifa_ica_model.dart';
import 'package:infoapp/pages/clientes/services/impuestos_service.dart';
import 'package:infoapp/pages/clientes/services/ciudades_api_service.dart';
import 'package:infoapp/pages/clientes/services/tarifas_ica_service.dart';
import 'package:infoapp/widgets/searchable_select_field.dart';

class ImpuestosManagerDialog extends StatefulWidget {
  const ImpuestosManagerDialog({super.key});

  @override
  State<ImpuestosManagerDialog> createState() => _ImpuestosManagerDialogState();
}

class _ImpuestosManagerDialogState extends State<ImpuestosManagerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;

  // Global Tax State
  List<ImpuestoModel> _impuestosGlobales = [];
  final _globalFormKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _porcentajeCtrl = TextEditingController();
  final _basePesosCtrl = TextEditingController();
  String _tipoImpuestoGlobal = 'IVA';
  int? _editingGlobalId;

  // ICA Territorial State
  List<TarifaIcaModel> _tarifasIca = [];
  List<CiudadModel> _ciudadesDisponibles = [];
  CiudadModel? _selectedCiudad;
  final _icaFormKey = GlobalKey<FormState>();
  final _tarifaIcaCtrl = TextEditingController();
  final _baseIcaCtrl = TextEditingController();
  final _ciudadExcepcionCtrl = TextEditingController();
  int? _editingIcaId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ImpuestosService.listarImpuestos(),
      TarifasIcaService.listarTarifas(),
      CiudadesApiService.listarCiudades(),
    ]);

    if (mounted) {
      setState(() {
        _impuestosGlobales = results[0] as List<ImpuestoModel>;
        _tarifasIca = results[1] as List<TarifaIcaModel>;
        final todasCiudades = results[2] as List<CiudadModel>;

        // Filtrar ciudades que ya tienen tarifa (Selector Inteligente)
        final idsConfigurados = _tarifasIca.map((t) => t.ciudadId).toSet();
        _ciudadesDisponibles =
            todasCiudades.where((c) {
              if (_editingIcaId != null) {
                final currentEditing = _tarifasIca.firstWhere(
                  (t) => t.id == _editingIcaId,
                );
                if (c.id == currentEditing.ciudadId) return true;
              }
              return !idsConfigurados.contains(c.id);
            }).toList();

        _loading = false;
      });
    }
  }

  // --- LÓGICA GLOBAL ---
  void _limpiarGlobal() {
    _editingGlobalId = null;
    _nombreCtrl.clear();
    _porcentajeCtrl.clear();
    _basePesosCtrl.clear();
    setState(() => _tipoImpuestoGlobal = 'IVA');
  }

  void _cargarGlobalParaEdicion(ImpuestoModel imp) {
    setState(() {
      _editingGlobalId = imp.id;
      _nombreCtrl.text = imp.nombreImpuesto;
      _porcentajeCtrl.text = imp.porcentaje.toString();
      _basePesosCtrl.text = imp.baseMinimaPesos.toString();
      _tipoImpuestoGlobal = imp.tipoImpuesto;
    });
  }

  Future<void> _guardarGlobal() async {
    if (!_globalFormKey.currentState!.validate()) return;

    final impuesto = ImpuestoModel(
      id: _editingGlobalId,
      nombreImpuesto: _nombreCtrl.text.trim(),
      tipoImpuesto: _tipoImpuestoGlobal,
      porcentaje: double.tryParse(_porcentajeCtrl.text) ?? 0,
      baseMinimaPesos: double.tryParse(_basePesosCtrl.text) ?? 0,
      activo: true,
    );

    setState(() => _loading = true);
    final success =
        _editingGlobalId == null
            ? await ImpuestosService.crearImpuesto(impuesto)
            : await ImpuestosService.actualizarImpuesto(impuesto);

    if (success) {
      _limpiarGlobal();
      await _cargarDatos();
    }
    setState(() => _loading = false);
  }

  // --- LÓGICA ICA TERRITORIAL ---
  void _limpiarIca() async {
    setState(() {
      _editingIcaId = null;
      _selectedCiudad = null;
    });
    _tarifaIcaCtrl.clear();
    _baseIcaCtrl.clear();
    _ciudadExcepcionCtrl.clear();
    await _cargarDatos(); // Refresh filters
  }

  Future<void> _cargarIcaParaEdicion(TarifaIcaModel t) async {
    setState(() {
      _editingIcaId = t.id;
      _tarifaIcaCtrl.text = t.tarifaXMil.toString();
      _baseIcaCtrl.text = t.baseMinimaUvt.toString();
      _ciudadExcepcionCtrl.text = t.ciudadNombre ?? '';
    });
    // Forzar recarga de datos para que el selector inteligente incluya la ciudad en edición
    await _cargarDatos();

    setState(() {
      _selectedCiudad = _ciudadesDisponibles.firstWhere(
        (c) => c.id == t.ciudadId,
        orElse: () => CiudadModel(id: t.ciudadId, nombre: t.ciudadNombre),
      );
    });
  }

  Future<void> _guardarIca() async {
    final bool formValido = _icaFormKey.currentState!.validate();

    if (!formValido) return;

    if (_selectedCiudad == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, seleccione una ciudad de la lista'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final tarifa = TarifaIcaModel(
      id: _editingIcaId,
      ciudadId: _selectedCiudad!.id!,
      tarifaXMil: double.tryParse(_tarifaIcaCtrl.text) ?? 0,
      baseMinimaUvt: double.tryParse(_baseIcaCtrl.text) ?? 0,
    );

    setState(() => _loading = true);
    final success =
        _editingIcaId == null
            ? await TarifasIcaService.crearTarifa(tarifa)
            : await TarifasIcaService.actualizarTarifa(tarifa);

    if (success) {
      _limpiarIca();
    }
    setState(() => _loading = false);
  }

  Future<void> _eliminarIca(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirmar Eliminación'),
            content: const Text('¿Desea borrar esta excepción municipal?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Borrar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (ok == true) {
      setState(() => _loading = true);
      await TarifasIcaService.eliminarTarifa(id);
      await _cargarDatos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 900, // Layout más ancho para gestión tipo ERP
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: Theme.of(context).primaryColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Arquitectura Tributaria',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(icon: Icon(Icons.public), text: 'Configuración Global'),
                Tab(
                  icon: Icon(Icons.map),
                  text: 'Excepciones ReteICA (Ciudad)',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildGlobalTab(), _buildIcaTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalTab() {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Formulario a la izquierda
              Expanded(
                flex: 2,
                child: Form(
                  key: _globalFormKey,
                  child: Card(
                    elevation: 0,
                    color: Colors.grey[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configurar Impuesto Maestro',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _tipoImpuestoGlobal,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de Impuesto',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'IVA',
                                child: Text('IVA'),
                              ),
                              DropdownMenuItem(
                                value: 'RETEFUENTE',
                                child: Text('RETEFUENTE'),
                              ),
                              DropdownMenuItem(
                                value: 'RETEICA',
                                child: Text('RETEICA (Global)'),
                              ),
                              DropdownMenuItem(
                                value: 'RETEIVA',
                                child: Text('RETEIVA'),
                              ),
                            ],
                            onChanged:
                                (v) => setState(() => _tipoImpuestoGlobal = v!),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nombreCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Etiqueta Visual',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _porcentajeCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Porcentaje %',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.percent),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _basePesosCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Base Mínima (\$)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.attach_money),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              if (_editingGlobalId != null)
                                TextButton(
                                  onPressed: _limpiarGlobal,
                                  child: const Text('Cancelar'),
                                ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: _guardarGlobal,
                                icon: const Icon(Icons.save),
                                label: Text(
                                  _editingGlobalId == null
                                      ? 'Registrar Global'
                                      : 'Actualizar Global',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Tabla a la derecha
              Expanded(
                flex: 3,
                child:
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                          itemCount: _impuestosGlobales.length,
                          itemBuilder: (context, index) {
                            final imp = _impuestosGlobales[index];
                            return ListTile(
                              title: Text(
                                imp.nombreImpuesto,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${imp.tipoImpuesto} | Tarifa: ${imp.porcentaje}% | Base: \$${imp.baseMinimaPesos}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _cargarGlobalParaEdicion(imp),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIcaTab() {
    return Column(
      children: [
        // Formulario de Inserción ICA
        Padding(
          padding: const EdgeInsets.only(
            top: 8.0,
          ), // Espacio para etiquetas flotantes
          child: Form(
            key: _icaFormKey,
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start, // Cambiado a start para mejor alineación de etiquetas
              children: [
                Expanded(
                  flex: 3,
                  child: SearchableSelectField(
                    label: 'Ciudad para Excepción',
                    controller: _ciudadExcepcionCtrl,
                    items:
                        _ciudadesDisponibles
                            .map((c) => c.nombre ?? '')
                            .toList(),
                    prefixIcon: Icons.location_city,
                    onChanged: (v) {
                      if (v.isEmpty) {
                        setState(() => _selectedCiudad = null);
                        return;
                      }
                      try {
                        final ciudad = _ciudadesDisponibles.firstWhere(
                          (c) => c.nombre == v,
                        );
                        setState(() => _selectedCiudad = ciudad);
                      } catch (_) {
                        setState(() => _selectedCiudad = null);
                      }
                    },
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Seleccione una ciudad'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _tarifaIcaCtrl,
                    decoration: InputDecoration(
                      labelText: 'Tarifa x 1000',
                      labelStyle: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: const OutlineInputBorder(),
                      suffixText: '‰',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (double.tryParse(v) == null) return 'Inválido';
                      return null;
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _baseIcaCtrl,
                    decoration: InputDecoration(
                      labelText: 'Base (UVT)',
                      labelStyle: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (double.tryParse(v) == null) return 'Inválido';
                      return null;
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 4.0,
                  ), // Alinear botón con campos
                  child: ElevatedButton(
                    onPressed: _guardarIca,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 24,
                      ),
                    ),
                    child: Icon(
                      _editingIcaId == null ? Icons.add : Icons.check,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Tabla de Tarifas ICA
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Municipio',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Tarifa x 1000',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Base (UVT)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Acciones',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows:
                      _tarifasIca
                          .map(
                            (t) => DataRow(
                              cells: [
                                DataCell(Text(t.ciudadNombre ?? '')),
                                DataCell(Text('${t.tarifaXMil}‰')),
                                DataCell(Text('${t.baseMinimaUvt} UVT')),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        onPressed:
                                            () => _cargarIcaParaEdicion(t),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        onPressed: () => _eliminarIca(t.id!),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
