import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:infoapp/core/utils/download_utils.dart' as dl;
import '../../models/funcionario_model.dart';
import '../../services/servicios_api_service.dart';
// Eliminado: servicios de staff, se usan métodos propios de funcionarios
import 'package:infoapp/features/auth/domain/permission_store.dart';

class FuncionariosCrudModal extends StatefulWidget {
  final int? seleccionadoId;
  final ValueChanged<FuncionarioModel>? onSeleccionar;
  final int? clienteId;

  const FuncionariosCrudModal({
    super.key,
    this.seleccionadoId,
    this.onSeleccionar,
    this.clienteId,
  });

  @override
  State<FuncionariosCrudModal> createState() => _FuncionariosCrudModalState();
}

class _FuncionariosCrudModalState extends State<FuncionariosCrudModal> {
  List<FuncionarioModel> _funcionarios = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isProcessing = false; // Acciones de Excel

  // Formulario de creación/edición
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _cargoController = TextEditingController();
  final TextEditingController _empresaController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  FuncionarioModel? _editando;
  bool _isSaving = false;

  // Nodo de enfoque estable para evitar errores en Web
  final FocusNode _cargoFocusNode = FocusNode();
  final FocusNode _empresaFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _cargarFuncionarios();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cargoController.dispose();
    _empresaController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _cargoFocusNode.dispose();
    _empresaFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarFuncionarios() async {
    setState(() => _isLoading = true);
    try {
      final list = await ServiciosApiService.listarFuncionarios(
        clienteId: widget.clienteId,
      );
      setState(() => _funcionarios = list);
    } catch (e) {
      _showSnack('Error cargando funcionarios: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<FuncionarioModel> get _filtrados {
    final activos = _funcionarios.where((f) => f.activo).toList();
    if (_searchQuery.trim().isEmpty) return activos;
    final q = _searchQuery.toLowerCase();
    return activos
        .where((f) => f.descripcion.toLowerCase().contains(q))
        .toList();
  }

  // Getters para autocompletado (valores únicos)
  List<String> get _uniqueCargos {
    return _funcionarios
        .map((f) => f.cargo)
        .where((c) => c != null && c.isNotEmpty)
        .map((c) => c!)
        .toSet()
        .toList();
  }

  List<String> get _uniqueEmpresas {
    return _funcionarios
        .map((f) => f.empresa)
        .where((e) => e != null && e.isNotEmpty)
        .map((e) => e!)
        .toSet()
        .toList();
  }

  Future<void> _descargarPlantilla() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      // Generar plantilla Excel local para funcionarios
      final excel = Excel.createExcel();
      final sheet = excel['Funcionarios'];
      final headers = ['ID','Nombre','Cargo','Empresa','Activo'];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#EEEEEE'),
          fontFamily: 'Arial',
        );
      }
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('Info App'),
        TextCellValue('Desarrollo'),
        TextCellValue('Novatech Development'),
        TextCellValue('Sí'),
      ]);
      final bytes = excel.encode() ?? <int>[];
      await dl.saveBytes(
        'plantilla_funcionarios.xlsx',
        Uint8List.fromList(bytes),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      _showSnack('Plantilla Excel de funcionarios descargada');
    } catch (e) {
      _showSnack('Error generando plantilla: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportarExcel() async {
    if (_isProcessing) return;
    // Permiso para exportar datos de servicios
    final store = PermissionStore.instance;
    if (!store.can('servicios_autorizado_por', 'exportar')) {
      _showSnack('No tienes permiso para exportar', isError: true);
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final resp = await ServiciosApiService.exportarYGuardarExcel(
        incluirInactivos: false,
      );
      if (resp.isSuccess) {
        _showSnack(resp.message ?? 'Exportación Excel completada');
      } else {
        _showSnack(resp.error ?? 'Error al exportar funcionarios', isError: true);
      }
    } catch (e) {
      _showSnack('Error exportando funcionarios: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _importarExcel() async {
    if (_isProcessing) return;
    final store = PermissionStore.instance;
    if (!store.can('servicios_autorizado_por', 'crear')) {
      _showSnack('No tienes permiso para importar', isError: true);
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx','xls'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final Uint8List? bytes = file.bytes;

      if (bytes == null) {
        _showSnack('No se pudieron leer los bytes del archivo', isError: true);
        return;
      }

      setState(() => _isProcessing = true);
      final resp = await ServiciosApiService.importarFuncionariosDesdeExcel(
        excelBytes: bytes,
        modo: 'crear_o_actualizar',
        sobrescribirExistentes: false,
      );

      if (resp.isSuccess && resp.data != null) {
        final resultados = resp.data!['resultados'] as Map<String, dynamic>?;
        await _cargarFuncionarios();
        if (resultados != null) {
          final ins = resultados['insertados'] ?? 0;
          final act = resultados['actualizados'] ?? 0;
          final omi = resultados['omitidos'] ?? 0;
          final err = (resultados['errores'] as List?)?.length ?? 0;
          _showSnack('Importación: $ins nuevos, $act actualizados, $omi omitidos, $err errores');
        } else {
          _showSnack('Importación completada', isError: false);
        }
      } else {
        _showSnack(resp.error ?? 'Error al importar funcionarios', isError: true);
      }
    } catch (e) {
      _showSnack('Error importando archivo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnack(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error : Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _nuevoFuncionario() {
    final store = PermissionStore.instance;
    if (!store.can('servicios_autorizado_por', 'crear')) {
      _showSnack('No tienes permiso para crear funcionarios', isError: true);
      return;
    }
    setState(() {
      _editando = null;
      _nombreController.clear();
      _cargoController.clear();
      _empresaController.clear();
      _telefonoController.clear();
      _emailController.clear();
    });
    _mostrarFormulario();
  }

  void _editarFuncionario(FuncionarioModel f) {
    final store = PermissionStore.instance;
    if (!store.can('servicios_autorizado_por', 'actualizar')) {
      _showSnack('No tienes permiso para editar', isError: true);
      return;
    }
    setState(() {
      _editando = f;
      _nombreController.text = f.nombre;
      _cargoController.text = f.cargo ?? '';
      _empresaController.text = f.empresa ?? '';
      _telefonoController.text = f.telefono ?? '';
      _emailController.text = f.correo ?? '';
    });
    _mostrarFormulario();
  }

  void _mostrarFormulario() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(_editando == null ? Icons.person_add : Icons.edit,
                  color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(_editando == null ? 'Nuevo Funcionario' : 'Editar Funcionario'),
            ],
          ),
          content: Form(
            key: _formKey,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'El nombre es obligatorio';
                      }
                      if (v.trim().length < 3) {
                        return 'Debe tener al menos 3 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildAutocompleteField(
                    controller: _cargoController,
                    focusNode: _cargoFocusNode,
                    label: 'Cargo',
                    icon: Icons.work,
                    options: _uniqueCargos,
                    helperText: 'Opcional. Seleccione o escriba uno nuevo.',
                  ),
                  const SizedBox(height: 12),
                  _buildAutocompleteField(
                    controller: _empresaController,
                    focusNode: _empresaFocusNode,
                    label: 'Empresa',
                    icon: Icons.business,
                    options: _uniqueEmpresas,
                    helperText: 'Opcional. Seleccione o escriba una nueva.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.phone),
                      helperText: 'Opcional',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.email),
                      helperText: 'Opcional',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      Navigator.pop(context);
                      setState(() {
                        _isSaving = false;
                      });
                    },
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _guardar,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(_editando == null ? Icons.save : Icons.update),
              label: Text(_isSaving
                  ? 'Guardando...'
                  : (_editando == null ? 'Crear' : 'Actualizar')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final store = PermissionStore.instance;
    if (_editando == null && !store.can('servicios_autorizado_por', 'crear')) {
      _showSnack('No tienes permiso para crear', isError: true);
      return;
    }
    if (_editando != null && !store.can('servicios_autorizado_por', 'actualizar')) {
      _showSnack('No tienes permiso para actualizar', isError: true);
      return;
    }

    final nombre = _nombreController.text.trim();
    final cargo = _cargoController.text.trim();
    final empresa = _empresaController.text.trim();
    final telefono = _telefonoController.text.trim();
    final email = _emailController.text.trim();

    setState(() => _isSaving = true);

    try {
      if (_editando == null) {
        final resultado = await ServiciosApiService.crearFuncionario(
          nombre: nombre,
          cargo: cargo.isNotEmpty ? cargo : null,
          empresa: empresa.isNotEmpty ? empresa : null,
          telefono: telefono.isNotEmpty ? telefono : null,
          correo: email.isNotEmpty ? email : null,
          clienteId: widget.clienteId,
        );

        if (resultado.isSuccess && resultado.data != null) {
          Navigator.pop(context);
          await _cargarFuncionarios();
          _showSnack(resultado.message ?? 'Funcionario creado exitosamente');
          if (widget.onSeleccionar != null) {
            widget.onSeleccionar!(resultado.data!);
          }
        } else {
          _showSnack(resultado.error ?? 'Error al crear funcionario', isError: true);
        }
      } else {
        final resultado = await ServiciosApiService.actualizarFuncionario(
          funcionarioId: _editando!.id,
          nombre: nombre,
          cargo: cargo.isNotEmpty ? cargo : null,
          empresa: empresa.isNotEmpty ? empresa : null,
          telefono: telefono.isNotEmpty ? telefono : null,
          correo: email.isNotEmpty ? email : null,
          clienteId: widget.clienteId,
        );

        if (resultado.isSuccess) {
          Navigator.pop(context);
          await _cargarFuncionarios();
          _showSnack(resultado.message ?? 'Funcionario actualizado exitosamente');
        } else {
          _showSnack(resultado.error ?? 'Error al actualizar', isError: true);
        }
      }
    } catch (e) {
      _showSnack('Error de conexión: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _eliminar(FuncionarioModel f) async {
    final store = PermissionStore.instance;
    if (!store.can('servicios_autorizado_por', 'eliminar')) {
      _showSnack('No tienes permiso para eliminar', isError: true);
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Funcionario'),
        content: Text('¿Está seguro de eliminar a "${f.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final resultado = await ServiciosApiService.eliminarFuncionario(f.id);
      if (resultado.isSuccess) {
        await _cargarFuncionarios();
        _showSnack(resultado.message ?? 'Funcionario eliminado');
      } else {
        _showSnack(resultado.error ?? 'Error al eliminar', isError: true);
      }
    } catch (e) {
      _showSnack('Error de conexión: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PermissionStore.instance;
    final canCrear = store.can('servicios_autorizado_por', 'crear');
    final canActualizar = store.can('servicios_autorizado_por', 'actualizar');
    final canEliminar = store.can('servicios_autorizado_por', 'eliminar');
    final canExportar = store.can('servicios_autorizado_por', 'exportar');
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.92,
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.manage_accounts, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Gestionar Funcionarios',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (canExportar || canCrear)
                    PopupMenuButton<String>(
                      tooltip: 'Acciones de datos',
                      icon: const Icon(Icons.cloud_download, color: Colors.white),
                      onSelected: (value) async {
                        switch (value) {
                          case 'plantilla':
                            await _descargarPlantilla();
                            break;
                          case 'exportar':
                            await _exportarExcel();
                            break;
                          case 'importar':
                            await _importarExcel();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (canExportar) ...[
                          const PopupMenuItem(
                            value: 'plantilla',
                            child: ListTile(
                              leading: Icon(Icons.description),
                              title: Text('Descargar plantilla (Excel)'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'exportar',
                            child: ListTile(
                              leading: Icon(Icons.grid_on),
                              title: Text('Exportar funcionarios (Excel)'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                        if (canCrear)
                          const PopupMenuItem(
                            value: 'importar',
                            child: ListTile(
                              leading: Icon(Icons.upload_file),
                              title: Text('Importar funcionarios (Excel)'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                  if (canCrear)
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      tooltip: 'Nuevo funcionario',
                      onPressed: _nuevoFuncionario,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Buscador
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar funcionario...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),

            // Lista
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
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
                            final isSelected = widget.seleccionadoId != null && f.id == widget.seleccionadoId;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                  child: const Icon(Icons.person, color: Colors.blue),
                                ),
                                title: Text(f.nombre),
                                subtitle: Text([
                                  f.cargo,
                                  f.empresa,
                                ].whereType<String>().where((s) => s.isNotEmpty).join(' · ')),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected)
                                      const Icon(Icons.check_circle, color: Colors.green),
                                    if (canActualizar)
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.orange),
                                        tooltip: 'Editar',
                                        onPressed: () => _editarFuncionario(f),
                                      ),
                                    if (canEliminar)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        tooltip: 'Eliminar',
                                        onPressed: () => _eliminar(f),
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  if (widget.onSeleccionar != null) {
                                    widget.onSeleccionar!(f);
                                  }
                                  Navigator.pop(context);
                                },
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

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required List<String> options,
    String? helperText,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: focusNode,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return options.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(icon),
                helperText: helperText,
                suffixIcon: options.isNotEmpty
                    ? PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down),
                        tooltip: 'Ver todos',
                        onSelected: (String value) {
                          textEditingController.text = value;
                        },
                        itemBuilder: (BuildContext context) {
                          return options.map<PopupMenuItem<String>>((String value) {
                            return PopupMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList();
                        },
                      )
                    : null,
              ),
              onFieldSubmitted: (String value) {
                onFieldSubmitted();
              },
            );
          },
          optionsViewBuilder: (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Container(
                  width: constraints.maxWidth,
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String option = options.elementAt(index);
                        return ListTile(
                          title: Text(option),
                          onTap: () {
                            onSelected(option);
                          },
                          hoverColor: Colors.grey.shade100,
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
