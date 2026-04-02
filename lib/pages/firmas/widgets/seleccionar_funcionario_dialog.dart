import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../servicios/models/funcionario_model.dart';
import '../../servicios/services/servicios_api_service.dart';

class SeleccionarFuncionarioDialog extends StatefulWidget {
  final int? clienteId;
  const SeleccionarFuncionarioDialog({super.key, this.clienteId});

  @override
  State<SeleccionarFuncionarioDialog> createState() =>
      _SeleccionarFuncionarioDialogState();
}

class _SeleccionarFuncionarioDialogState
    extends State<SeleccionarFuncionarioDialog> {
  List<FuncionarioModel> _funcionarios = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarFuncionarios();
  }

  Future<void> _cargarFuncionarios() async {
    setState(() => _isLoading = true);
    try {
      final list = await ServiciosApiService.listarFuncionarios(
        clienteId: widget.clienteId,
      );
      setState(() => _funcionarios = list.where((f) => f.activo).toList());
    } catch (e) {
      _mostrarSnack('Error cargando funcionarios: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<FuncionarioModel> get _filtrados {
    if (_searchQuery.isEmpty) return _funcionarios;
    final q = _searchQuery.toLowerCase();
    return _funcionarios
        .where((f) => f.descripcion.toLowerCase().contains(q))
        .toList();
  }

  void _mostrarSnack(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? PhosphorIcons.warningCircle()
                  : PhosphorIcons.checkCircle(),
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.identificationBadge(),
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Seleccionar Funcionario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(PhosphorIcons.plusCircle(), color: Colors.white),
                    tooltip: 'Crear nuevo funcionario',
                    onPressed: () => _mostrarDialogoGestionarFuncionario(),
                  ),
                  IconButton(
                    icon: Icon(PhosphorIcons.x(), color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // ✅ Header Actions

            // Buscador
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar funcionario...',
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // Lista
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtrados.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorIcons.magnifyingGlass(),
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No hay funcionarios disponibles'
                                  : 'No se encontraron resultados',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtrados.length,
                        itemBuilder: (context, index) {
                          final f = _filtrados[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1),
                                child: Icon(
                                  PhosphorIcons.user(),
                                  color: Colors.blue,
                                ),
                              ),
                              title: Text(f.nombre),
                              subtitle: Text(
                                [f.cargo, f.empresa]
                                    .whereType<String>()
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      PhosphorIcons.pencilSimple(),
                                      color: Colors.grey,
                                    ),
                                    onPressed:
                                        () =>
                                            _mostrarDialogoGestionarFuncionario(
                                              funcionario: f,
                                            ),
                                  ),
                                  Icon(PhosphorIcons.check()),
                                ],
                              ),
                              onTap: () => Navigator.pop(context, f),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoGestionarFuncionario({
    FuncionarioModel? funcionario,
  }) async {
    final esEdicion = funcionario != null;
    final nombreCtrl = TextEditingController(text: funcionario?.nombre ?? '');
    final telefonoCtrl = TextEditingController(
      text: funcionario?.telefono ?? '',
    );
    final correoCtrl = TextEditingController(text: funcionario?.correo ?? '');

    // Obtener listas únicas para autocompletado
    final cargosExistentes =
        _funcionarios
            .map((f) => f.cargo)
            .where((c) => c != null && c.isNotEmpty)
            .map((c) => c!)
            .toSet()
            .toList()
          ..sort();

    final empresasExistentes =
        _funcionarios
            .map((f) => f.empresa)
            .where((e) => e != null && e.isNotEmpty)
            .map((e) => e!)
            .toSet()
            .toList()
          ..sort();

    // Variables para capturar el valor seleccionado o escrito
    String? cargoSeleccionado = funcionario?.cargo;
    String? empresaSeleccionada = funcionario?.empresa;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(esEdicion ? 'Editar Funcionario' : 'Nuevo Funcionario'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo *',
                      hintText: 'Ej. Juan Pérez',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // Autocomplete Cargo
                  Autocomplete<String>(
                    initialValue: TextEditingValue(
                      text: cargoSeleccionado ?? '',
                    ),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<String>.empty();
                      }
                      return cargosExistentes.where((String option) {
                        return option.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        );
                      });
                    },
                    onSelected: (String selection) {
                      cargoSeleccionado = selection;
                    },
                    fieldViewBuilder: (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      // Si es edición y hay dato inicial, el controller debe tenerlo
                      if (textEditingController.text.isEmpty &&
                          cargoSeleccionado != null) {
                        textEditingController.text = cargoSeleccionado!;
                      }

                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onChanged: (val) => cargoSeleccionado = val,
                        decoration: InputDecoration(
                          labelText: 'Cargo',
                          hintText: 'Ej. Supervisor',
                          suffixIcon: Icon(PhosphorIcons.caretDown()),
                        ),
                        textCapitalization: TextCapitalization.words,
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Autocomplete Empresa
                  Autocomplete<String>(
                    initialValue: TextEditingValue(
                      text: empresaSeleccionada ?? '',
                    ),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<String>.empty();
                      }
                      return empresasExistentes.where((String option) {
                        return option.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        );
                      });
                    },
                    onSelected: (String selection) {
                      empresaSeleccionada = selection;
                    },
                    fieldViewBuilder: (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      // Si es edición y hay dato inicial, el controller debe tenerlo
                      if (textEditingController.text.isEmpty &&
                          empresaSeleccionada != null) {
                        textEditingController.text = empresaSeleccionada!;
                      }
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onChanged: (val) => empresaSeleccionada = val,
                        decoration: InputDecoration(
                          labelText: 'Empresa',
                          hintText: 'Ej. Acme Corp',
                          suffixIcon: Icon(PhosphorIcons.caretDown()),
                        ),
                        textCapitalization: TextCapitalization.words,
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: telefonoCtrl,
                    decoration: InputDecoration(
                      labelText: 'Teléfono',
                      hintText: 'Ej. 3001234567',
                      prefixIcon: Icon(PhosphorIcons.phone()),
                    ),
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: correoCtrl,
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      hintText: 'Ej. usuario@empresa.com',
                      prefixIcon: Icon(PhosphorIcons.envelope()),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final nombre = nombreCtrl.text.trim();
                  if (nombre.isEmpty) {
                    return;
                  }
                  Navigator.pop(context); // Cerrar diálogo de formulario

                  // Mostrar carga
                  setState(() => _isLoading = true);

                  // Variable para el resultado
                  dynamic result;

                  if (esEdicion) {
                    // ACTUALIZAR
                    result = await ServiciosApiService.actualizarFuncionario(
                      funcionarioId: funcionario.id,
                      nombre: nombre,
                      cargo: cargoSeleccionado,
                      empresa: empresaSeleccionada,
                      telefono: telefonoCtrl.text.trim(),
                      correo: correoCtrl.text.trim(),
                      clienteId: widget.clienteId,
                    );
                  } else {
                    // CREAR
                    result = await ServiciosApiService.crearFuncionario(
                      nombre: nombre,
                      cargo: cargoSeleccionado,
                      empresa: empresaSeleccionada,
                      telefono: telefonoCtrl.text.trim(),
                      correo: correoCtrl.text.trim(),
                      clienteId: widget.clienteId,
                    );
                  }

                  if (mounted) {
                    setState(() => _isLoading = false);
                    if (result.isSuccess && result.data != null) {
                      _mostrarSnack(
                        'Funcionario ${esEdicion ? 'actualizado' : 'creado'} exitosamente',
                      );

                      // Actualizar lista
                      setState(() {
                        if (esEdicion) {
                          final index = _funcionarios.indexWhere(
                            (f) => f.id == funcionario.id,
                          );
                          if (index != -1) {
                            _funcionarios[index] =
                                result.data!; // Reemplazar con el actualizado
                          }
                        } else {
                          _funcionarios.add(result.data!);
                        }
                        // Reordenar
                        _funcionarios.sort(
                          (a, b) => a.nombre.compareTo(b.nombre),
                        );
                      });
                    } else {
                      _mostrarSnack(
                        result.error ?? 'Error procesando funcionario',
                        isError: true,
                      );
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }
}
