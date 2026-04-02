import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:infoapp/pages/clientes/controllers/clientes_controller.dart';
import 'package:infoapp/pages/clientes/pages/especialidades_page.dart';
import 'package:infoapp/pages/clientes/models/cliente_model.dart';
import 'package:infoapp/pages/clientes/models/especialidad_model.dart';
import 'package:infoapp/pages/clientes/models/cliente_perfil_model.dart';
import 'package:infoapp/pages/clientes/services/especialidades_service.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:infoapp/core/utils/currency_utils.dart';
import 'package:infoapp/widgets/currency_input_formatter.dart';
import 'package:infoapp/pages/servicios/models/funcionario_model.dart';
import 'package:infoapp/widgets/searchable_select_field.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ClienteFormPage extends StatelessWidget {
  final ClienteModel? cliente;

  const ClienteFormPage({super.key, this.cliente});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ClientesController()..cargarDepartamentos(),
      child: _ClienteFormView(cliente: cliente),
    );
  }
}

class _ClienteFormView extends StatefulWidget {
  final ClienteModel? cliente;

  const _ClienteFormView({this.cliente});

  @override
  State<_ClienteFormView> createState() => _ClienteFormViewState();
}

class _ClienteFormViewState extends State<_ClienteFormView> {
  final _formKey = GlobalKey<FormState>();

  late String _tipoPersona;
  late TextEditingController _documentoCtrl;
  late TextEditingController _nombreCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _telPrincipalCtrl;
  late TextEditingController _telSecundarioCtrl;
  late TextEditingController _direccionCtrl;
  late TextEditingController _limiteCreditoCtrl;
  late TextEditingController _perfilCtrl; // Antes valorMo
  late TextEditingController _codigoCiiuCtrl;
  late TextEditingController _dvCtrl;
  late TextEditingController _emailFacturacionCtrl;
  late TextEditingController _departamentoCtrl;
  late TextEditingController _ciudadCtrl;

  String _regimenTributario = 'No Responsable de IVA';
  String _responsabilidadFiscalId = 'R-99-PN';
  bool _esAgenteRetenedor = false;
  bool _esAutorretenedor = false;
  bool _esGranContribuyente = false;

  int? _ciudadId;
  int? _departamentoId;
  bool _activo = true;
  bool _isSaving = false;
  bool _isLoadingDetails = false;

  List<ClientePerfilModel> _perfiles = [];
  final List<FuncionarioModel> _funcionariosLocales = []; // Para clientes nuevos

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;

    _tipoPersona = c?.tipoPersona ?? 'Natural';
    _documentoCtrl = TextEditingController(text: c?.documentoNit ?? '');
    _nombreCtrl = TextEditingController(text: c?.nombreCompleto ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _telPrincipalCtrl = TextEditingController(text: c?.telefonoPrincipal ?? '');
    _telSecundarioCtrl = TextEditingController(
      text: c?.telefonoSecundario ?? '',
    );
    _direccionCtrl = TextEditingController(text: c?.direccion ?? '');
    _limiteCreditoCtrl = TextEditingController(
      text: CurrencyUtils.format(c?.limiteCredito ?? 0),
    );
    _perfilCtrl = TextEditingController(text: c?.perfil ?? '');
    _codigoCiiuCtrl = TextEditingController(text: c?.codigoCiiu ?? '');
    _dvCtrl = TextEditingController(text: c?.dv ?? '');
    _emailFacturacionCtrl = TextEditingController(
      text: c?.emailFacturacion ?? '',
    );
    _departamentoCtrl = TextEditingController();
    _ciudadCtrl = TextEditingController();

    _regimenTributario = c?.regimenTributario ?? 'No Responsable de IVA';
    _responsabilidadFiscalId = c?.responsabilidadFiscalId ?? 'R-99-PN';
    _esAgenteRetenedor = c?.esAgenteRetenedor ?? false;
    _esAutorretenedor = c?.esAutorretenedor ?? false;
    _esGranContribuyente = c?.esGranContribuyente ?? false;

    _ciudadId = c?.ciudadId;
    _departamentoId = c?.departamentoId;
    _activo = c?.activo ?? true;

    // Si tenemos departamento, cargar sus ciudades
    if (_departamentoId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<ClientesController>(
          context,
          listen: false,
        ).cargarCiudades(departamentoId: _departamentoId);
      });
    }

    // Copiar perfiles iniciales (aunque suelen venir vacíos del listado)
    if (c?.perfiles != null) {
      _perfiles = List.from(c!.perfiles);
    }

    // Si es edición, cargar detalles completos (incluyendo perfiles)
    if (c?.id != null) {
      _cargarDetallesCompletos(c!.id!);
    }
  }

  Future<void> _cargarDetallesCompletos(int id) async {
    setState(() => _isLoadingDetails = true);
    // Esperar a que el frame termine para usar Provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = Provider.of<ClientesController>(
        context,
        listen: false,
      );
      final fullCliente = await controller.obtenerCliente(id);

      if (mounted) {
        if (fullCliente != null) {
          setState(() {
            _perfiles = List.from(fullCliente.perfiles);
            // Funcionarios se cargan en el controller, pero podemos sincronizar si es necesario
            // _funcionariosLocales se ignora en edición ya que se usa controller.funcionarios

            _perfilCtrl.text = fullCliente.perfil ?? '';
            _codigoCiiuCtrl.text = fullCliente.codigoCiiu ?? '';
            _dvCtrl.text = fullCliente.dv ?? '';
            _emailFacturacionCtrl.text = fullCliente.emailFacturacion ?? '';
            _regimenTributario =
                fullCliente.regimenTributario ?? 'No Responsable de IVA';
            _responsabilidadFiscalId =
                fullCliente.responsabilidadFiscalId ?? 'R-99-PN';
            _esAgenteRetenedor = fullCliente.esAgenteRetenedor ?? false;
            _esAutorretenedor = fullCliente.esAutorretenedor ?? false;
            _esGranContribuyente = fullCliente.esGranContribuyente ?? false;
          });
        }
        setState(() => _isLoadingDetails = false);
      }
    });
  }

  @override
  void dispose() {
    _documentoCtrl.dispose();
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telPrincipalCtrl.dispose();
    _telSecundarioCtrl.dispose();
    _direccionCtrl.dispose();
    _limiteCreditoCtrl.dispose();
    _perfilCtrl.dispose();
    _codigoCiiuCtrl.dispose();
    _dvCtrl.dispose();
    _emailFacturacionCtrl.dispose();
    _departamentoCtrl.dispose();
    _ciudadCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ciudadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor seleccione una ciudad')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final controller = Provider.of<ClientesController>(context, listen: false);

    final nuevoCliente = ClienteModel(
      id: widget.cliente?.id,
      tipoPersona: _tipoPersona,
      documentoNit: _documentoCtrl.text.trim(),
      nombreCompleto: _nombreCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      telefonoPrincipal: _telPrincipalCtrl.text.trim(),
      telefonoSecundario: _telSecundarioCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim(),
      ciudadId: _ciudadId,
      limiteCredito: CurrencyUtils.parse(_limiteCreditoCtrl.text),
      perfil: _perfilCtrl.text.trim(),
      regimenTributario: _regimenTributario,
      responsabilidadFiscalId: _responsabilidadFiscalId,
      codigoCiiu: _codigoCiiuCtrl.text.trim(),
      dv: _dvCtrl.text.trim(),
      emailFacturacion: _emailFacturacionCtrl.text.trim(),
      esAgenteRetenedor: _esAgenteRetenedor,
      esAutorretenedor: _esAutorretenedor,
      esGranContribuyente: _esGranContribuyente,
      perfiles: _perfiles,
      funcionarios: _funcionariosLocales, // Enviar lista local si es nuevo
      activo: _activo,
    );

    bool success;
    if (widget.cliente == null) {
      success = await controller.crearCliente(nuevoCliente);
    } else {
      success = await controller.actualizarCliente(nuevoCliente);
    }

    setState(() => _isSaving = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Guardado exitosamente')));
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar. Verifique los datos.'),
          ),
        );
      }
    }
  }

  Future<void> _agregarEspecialidad() async {
    var especialidades = await EspecialidadesService.listarEspecialidades();

    if (!mounted) return;

    EspecialidadModel? selected;
    if (especialidades.isNotEmpty) {
      selected = especialidades.first;
    }

    final valorCtrl = TextEditingController(
      text: CurrencyUtils.format(selected?.valorHr ?? 0),
    );

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: const Text('Agregar Tarifa'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<EspecialidadModel>(
                      initialValue: selected,
                      isExpanded: true,
                      items:
                          especialidades.map((e) {
                            return DropdownMenuItem(
                              value: e,
                              child: Text(e.nomEspeci),
                            );
                          }).toList(),
                      onChanged: (v) {
                        setStateDialog(() {
                          selected = v;
                          if (v != null) {
                            valorCtrl.text = CurrencyUtils.format(v.valorHr);
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Especialidad',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          color: Theme.of(context).primaryColor,
                          tooltip: 'Crear nueva especialidad',
                          onPressed: () async {
                            final nueva =
                                await _mostrarDialogoCrearEspecialidad();
                            if (nueva != null) {
                              final updatedList =
                                  await EspecialidadesService.listarEspecialidades();
                              setStateDialog(() {
                                especialidades = updatedList;
                                try {
                                  selected = especialidades.firstWhere(
                                    (e) => e.nomEspeci == nueva.nomEspeci,
                                  );
                                  valorCtrl.text = selected!.valorHr
                                      .toStringAsFixed(0);
                                } catch (_) {
                                  if (especialidades.isNotEmpty) {
                                    selected = especialidades.first;
                                  }
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valorCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Valor Tarifa',
                        prefixText: '\$ ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CurrencyInputFormatter(),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (selected == null) return;
                      final val = CurrencyUtils.parse(valorCtrl.text);

                      setState(() {
                        _perfiles.removeWhere(
                          (p) => p.especialidadId == selected!.id,
                        );

                        _perfiles.add(
                          ClientePerfilModel(
                            especialidadId: selected!.id!,
                            nomEspeci: selected!.nomEspeci,
                            valor: val,
                          ),
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Agregar'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<EspecialidadModel?> _mostrarDialogoCrearEspecialidad() async {
    final nombreCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return await showDialog<EspecialidadModel>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Nueva Especialidad'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Especialidad',
                    ),
                    validator:
                        (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final nueva = EspecialidadModel(
                      nomEspeci: nombreCtrl.text.trim(),
                    );
                    final success =
                        await EspecialidadesService.crearEspecialidad(nueva);
                    if (success) {
                      if (mounted) {
                        Navigator.pop(ctx, nueva);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Especialidad creada exitosamente'),
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error al crear especialidad'),
                          ),
                        );
                      }
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }

  // --- GESTIÓN DE FUNCIONARIOS ---

  Future<void> _gestionarFuncionario({FuncionarioModel? funcionario}) async {
    final isEditing = funcionario != null;
    final nombreCtrl = TextEditingController(text: funcionario?.nombre ?? '');
    final cargoCtrl = TextEditingController(text: funcionario?.cargo ?? '');

    // Valor inicial para empresa: si es nuevo o está vacío, sugerir el nombre del cliente
    String valorEmpresa = funcionario?.empresa ?? '';
    if (valorEmpresa.isEmpty) {
      if (widget.cliente != null) {
        valorEmpresa = widget.cliente!.nombreCompleto ?? '';
      } else {
        // En creación: tomar lo que el usuario haya escrito en el campo de nombre del cliente
        valorEmpresa = _nombreCtrl.text.trim();
      }
    }
    final empresaCtrl = TextEditingController(text: valorEmpresa);
    final telCtrl = TextEditingController(text: funcionario?.telefono ?? '');
    final emailCtrl = TextEditingController(text: funcionario?.correo ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<FuncionarioModel>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(isEditing ? 'Editar Funcionario' : 'Nuevo Funcionario'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre *'),
                      validator:
                          (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                    TextFormField(
                      controller: cargoCtrl,
                      decoration: const InputDecoration(labelText: 'Cargo'),
                    ),
                    TextFormField(
                      controller: empresaCtrl,
                      decoration: const InputDecoration(labelText: 'Empresa'),
                      readOnly: true,
                    ),
                    TextFormField(
                      controller: telCtrl,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                    ),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(
                      ctx,
                      FuncionarioModel(
                        id: funcionario?.id ?? 0,
                        nombre: nombreCtrl.text.trim(),
                        cargo: cargoCtrl.text.trim(),
                        empresa: empresaCtrl.text.trim(),
                        telefono: telCtrl.text.trim(),
                        correo: emailCtrl.text.trim(),
                        activo: true,
                        clienteId: widget.cliente?.id,
                      ),
                    );
                  }
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
    );

    if (result == null) return;

    final controller = Provider.of<ClientesController>(context, listen: false);

    if (widget.cliente?.id != null) {
      // EDICIÓN: Impacto directo en BD
      bool success;
      if (isEditing) {
        success = await controller.actualizarFuncionario(
          funcionarioId: result.id,
          nombre: result.nombre,
          cargo: result.cargo,
          empresa: result.empresa,
          telefono: result.telefono,
          correo: result.correo,
          clienteId: widget.cliente!.id,
        );
      } else {
        success = await controller.crearFuncionario(
          nombre: result.nombre,
          cargo: result.cargo,
          empresa: result.empresa,
          telefono: result.telefono,
          correo: result.correo,
          clienteId: widget.cliente!.id,
        );
      }

      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al procesar funcionario')),
        );
      }
    } else {
      // CREACIÓN: Gestión local
      setState(() {
        if (isEditing) {
          final index = _funcionariosLocales.indexOf(funcionario);
          if (index != -1) _funcionariosLocales[index] = result;
        } else {
          _funcionariosLocales.add(result);
        }
      });
    }
  }

  Future<void> _eliminarFuncionario(FuncionarioModel funcionario) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Eliminar Funcionario'),
            content: Text('¿Desea eliminar a ${funcionario.nombre}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final controller = Provider.of<ClientesController>(context, listen: false);

    if (widget.cliente?.id != null) {
      final success = await controller.eliminarFuncionario(
        funcionario.id,
        clienteId: widget.cliente!.id,
      );
      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar funcionario')),
        );
      }
    } else {
      setState(() {
        _funcionariosLocales.remove(funcionario);
      });
    }
  }

  String _calcularDV(String nit) {
    if (nit.isEmpty) return '';
    final List<int> vpri = [
      0,
      3,
      7,
      13,
      17,
      19,
      23,
      29,
      37,
      41,
      43,
      47,
      53,
      59,
      67,
      71,
    ];
    int x = 0;
    int y = 0;
    int z = nit.length;

    for (int i = 0; i < z; i++) {
      y = int.tryParse(nit[z - 1 - i]) ?? 0;
      x += y * vpri[i + 1];
    }

    y = x % 11;
    if (y > 1) {
      return (11 - y).toString();
    } else {
      return y.toString();
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSeccionFuncionarios(ClientesController controller) {
    final List<FuncionarioModel> list =
        widget.cliente?.id != null
            ? controller.funcionarios
            : _funcionariosLocales;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('FUNCIONARIOS AUTORIZADOS', PhosphorIcons.users()),
        _buildCard([
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Personal de Contacto',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                tooltip: 'Agregar Funcionario',
                color: Theme.of(context).primaryColor,
                onPressed: () => _gestionarFuncionario(),
              ),
            ],
          ),
          if (list.isEmpty)
            const Text(
              'No hay funcionarios asignados.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ...list.map(
            (f) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.1),
                child: Icon(
                  PhosphorIcons.user(),
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
              ),
              title: Text(f.nombre),
              subtitle: Text(
                f.cargo?.isNotEmpty == true ? f.cargo! : 'Sin cargo',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      PhosphorIcons.pencilSimple(),
                      color: Colors.blue,
                      size: 20,
                    ),
                    onPressed: () => _gestionarFuncionario(funcionario: f),
                  ),
                  IconButton(
                    icon: Icon(
                      PhosphorIcons.trash(),
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () => _eliminarFuncionario(f),
                  ),
                ],
              ),
              dense: true,
            ),
          ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ClientesController>(context);
    final esEdicion = widget.cliente != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar Cliente' : 'Nuevo Cliente'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingDetails) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                  ],

                  // BLOQUE 1: Identificación Técnica
                  _buildSectionTitle(
                    'BLOQUE 1: IDENTIFICACIÓN TÉCNICA',
                    PhosphorIcons.identificationCard(),
                  ),
                  _buildCard([
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _documentoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'NIT / Documento',
                              hintText: 'Ej: 900123456',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (v) {
                              if (_tipoPersona == 'Juridica') {
                                _dvCtrl.text = _calcularDV(v);
                              } else {
                                _dvCtrl.clear();
                              }
                            },
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Requerido';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _dvCtrl,
                            decoration: const InputDecoration(
                              labelText: 'DV',
                              counterText: '',
                              hintText: '0-9',
                            ),
                            maxLength: 1,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            // Permitimos edición manual para correcciones del usuario
                            validator: (v) {
                              if (_tipoPersona == 'Juridica' &&
                                  (v == null || v.isEmpty)) {
                                return '*';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _tipoPersona,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Organización *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Natural',
                          child: Text('Persona Natural'),
                        ),
                        DropdownMenuItem(
                          value: 'Juridica',
                          child: Text('Persona Jurídica'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _tipoPersona = v!;
                          if (_tipoPersona == 'Juridica') {
                            _dvCtrl.text = _calcularDV(_documentoCtrl.text);
                          } else {
                            _dvCtrl.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre / Razón Social *',
                      ),
                      validator:
                          (v) => v == null || v.isEmpty ? 'Requerido' : null,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailFacturacionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email de Recepción FE *',
                        hintText: 'notificaciones@empresa.com',
                        helperText: 'Vital para Facturación Electrónica',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido para FE';
                        if (!v.contains('@')) return 'Email inválido';
                        return null;
                      },
                    ),
                  ]),

                  // BLOQUE 2: Perfil Tributario (El "Cerebro")
                  _buildSectionTitle(
                    'BLOQUE 2: PERFIL TRIBUTARIO',
                    PhosphorIcons.brain(),
                  ),
                  _buildCard([
                    DropdownButtonFormField<String>(
                      initialValue: _responsabilidadFiscalId,
                      decoration: const InputDecoration(
                        labelText: 'Responsabilidad Fiscal Principal',
                        helperText: 'Código DIAN',
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'O-13',
                          child: Text('O-13 Gran Contribuyente'),
                        ),
                        DropdownMenuItem(
                          value: 'O-15',
                          child: Text('O-15 Autorretenedor'),
                        ),
                        DropdownMenuItem(
                          value: 'O-23',
                          child: Text('O-23 Agente de Retención IVA'),
                        ),
                        DropdownMenuItem(
                          value: 'R-99-PN',
                          child: Text('R-99-PN No responsable'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _responsabilidadFiscalId = v!;
                          // Lógica automática: Si es O-13, marcar Gran Contribuyente
                          if (v == 'O-13') {
                            _esGranContribuyente = true;
                          } else if (v == 'O-15') {
                            _esAutorretenedor = true;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _regimenTributario,
                      decoration: const InputDecoration(labelText: 'Régimen'),
                      items: const [
                        DropdownMenuItem(
                          value: 'No Responsable de IVA',
                          child: Text('No Responsable de IVA'),
                        ),
                        DropdownMenuItem(
                          value: 'Responsable de IVA',
                          child: Text('Responsable de IVA'),
                        ),
                        DropdownMenuItem(
                          value: 'Régimen Simple',
                          child: Text('Régimen Simple'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _regimenTributario = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _codigoCiiuCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Código CIIU (Actividad Económica)',
                        hintText: 'Ej. 6201',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ]),

                  // BLOQUE 3: Reglas de Retención (Switches)
                  _buildSectionTitle(
                    'BLOQUE 3: REGLAS DE RETENCIÓN',
                    PhosphorIcons.toggleLeft(),
                  ),
                  _buildCard([
                    SwitchListTile(
                      title: const Text('¿Sujeto a Retención en la Fuente?'),
                      subtitle: const Text(
                        'Valida base mínima UVT al facturar',
                      ),
                      value: _esAgenteRetenedor,
                      onChanged: (v) => setState(() => _esAgenteRetenedor = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('¿Aplica ReteIVA?'),
                      subtitle: Text(
                        _responsabilidadFiscalId == 'O-13'
                            ? 'Bloqueado: Automático por Gran Contribuyente (O-13)'
                            : 'Gran Contribuyente (Automático si O-13)',
                      ),
                      value:
                          _responsabilidadFiscalId == 'O-13'
                              ? true
                              : _esGranContribuyente,
                      onChanged:
                          _responsabilidadFiscalId == 'O-13'
                              ? null // Bloquear si es automático
                              : (v) => setState(() => _esGranContribuyente = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('¿Es Autorretenedor?'),
                      subtitle: const Text(
                        'No se le practica ReteFuente/ReteICA',
                      ),
                      value: _esAutorretenedor,
                      onChanged: (v) => setState(() => _esAutorretenedor = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    // Ubicación vinculada a ReteICA
                    (() {
                      if (_departamentoId != null &&
                          _departamentoCtrl.text.isEmpty &&
                          controller.departamentos.isNotEmpty) {
                        try {
                          _departamentoCtrl.text =
                              controller.departamentos
                                  .firstWhere((d) => d.id == _departamentoId)
                                  .nombre;
                        } catch (_) {}
                      }
                      return SearchableSelectField(
                        label: 'Departamento (ReteICA)',
                        controller: _departamentoCtrl,
                        items:
                            controller.departamentos
                                .map((d) => d.nombre)
                                .toList(),
                        prefixIcon: Icons.map_outlined,
                        onChanged: (v) {
                          try {
                            final dep = controller.departamentos.firstWhere(
                              (d) => d.nombre == v,
                            );
                            if (dep.id != _departamentoId) {
                              setState(() {
                                _departamentoId = dep.id;
                                _ciudadId = null;
                                _ciudadCtrl.clear();
                              });
                              controller.cargarCiudades(departamentoId: dep.id);
                            }
                          } catch (_) {}
                        },
                      );
                    })(),
                    const SizedBox(height: 16),
                    (() {
                      if (_ciudadId != null &&
                          _ciudadCtrl.text.isEmpty &&
                          controller.ciudades.isNotEmpty) {
                        try {
                          _ciudadCtrl.text =
                              controller.ciudades
                                  .firstWhere((c) => c.id == _ciudadId)
                                  .nombre ??
                              '';
                        } catch (_) {}
                      }
                      return SearchableSelectField(
                        label: 'Ciudad para ReteICA',
                        controller: _ciudadCtrl,
                        items:
                            controller.ciudades
                                .map((c) => c.nombre ?? '')
                                .toList(),
                        prefixIcon: Icons.location_city,
                        hint:
                            _departamentoId == null
                                ? 'Seleccione primero un departamento'
                                : 'Seleccione o busque una ciudad',
                        onChanged: (v) {
                          try {
                            final ciudad = controller.ciudades.firstWhere(
                              (c) => c.nombre == v,
                            );
                            setState(() => _ciudadId = ciudad.id);
                          } catch (_) {}
                        },
                      );
                    })(),
                  ]),

                  // ESPACIO PARA OTROS CONTACTOS
                  _buildSectionTitle(
                    'INFORMACIÓN DE CONTACTO',
                    PhosphorIcons.chatTeardropDots(),
                  ),
                  _buildCard([
                    TextFormField(
                      controller: _direccionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dirección Comercial *',
                      ),
                      maxLines: 2,
                      validator:
                          (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _telPrincipalCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono Principal *',
                            ),
                            keyboardType: TextInputType.phone,
                            validator:
                                (v) =>
                                    v == null || v.isEmpty ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _telSecundarioCtrl,
                            decoration: const InputDecoration(
                              labelText: 'WhatsApp / Celular',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // Sección de Tarifas
                  _buildSectionTitle(
                    'TARIFAS Y ESPECIALIDADES',
                    PhosphorIcons.currencyDollar(),
                  ),
                  _buildCard([
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Perfiles de Cobro',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.settings),
                              tooltip: 'Gestionar Especialidades',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const EspecialidadesPage(),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle),
                              color: Theme.of(context).primaryColor,
                              onPressed: _agregarEspecialidad,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_perfiles.isEmpty)
                      const Text(
                        'No hay tarifas asignadas.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ..._perfiles.map(
                      (p) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.nomEspeci ?? 'Especialidad'),
                        subtitle: Text('\$ ${CurrencyUtils.format(p.valor)}'),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _perfiles.remove(p)),
                        ),
                        dense: true,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),
                  _buildSeccionFuncionarios(controller),

                  const SizedBox(height: 16),
                  // Estado
                  if (esEdicion) ...[
                    _buildSectionTitle(
                      'GESTIÓN DE ESTADO',
                      PhosphorIcons.shieldCheck(),
                    ),
                    _buildCard([
                      SwitchListTile(
                        title: const Text('Cliente Activo'),
                        value: _activo,
                        onChanged: (v) => setState(() => _activo = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ]),
                  ],

                  const SizedBox(height: 80), // Espacio para el botón
                ],
              ),
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _guardar,
        backgroundColor: context.primaryColor,
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text('Guardar', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
