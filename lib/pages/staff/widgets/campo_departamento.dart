import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:dio/dio.dart';
import 'package:infoapp/core/env/server_config.dart';

// MODELO DE DEPARTAMENTO
class DepartmentModel {
  final int id;
  final String name;
  final String? description;
  final int? managerId;
  final String? managerName;
  final String? managerEmail;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasManager;
  final int totalEmployees;
  final int activeEmployees;
  final int inactiveEmployees;

  DepartmentModel({
    required this.id,
    required this.name,
    this.description,
    this.managerId,
    this.managerName,
    this.managerEmail,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.hasManager,
    this.totalEmployees = 0,
    this.activeEmployees = 0,
    this.inactiveEmployees = 0,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      managerId: json['manager_id'],
      managerName: json['manager_name'],
      managerEmail: json['manager_email'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      hasManager: json['has_manager'] ?? false,
      totalEmployees: json['total_employees'] ?? 0,
      activeEmployees: json['active_employees'] ?? 0,
      inactiveEmployees: json['inactive_employees'] ?? 0,
    );
  }

  String get descripcion => name;

  String get displayText {
    if (managerName != null) {
      return '$name (Manager: $managerName)';
    }
    return name;
  }

  bool get canBeDeleted => activeEmployees == 0;
}

// SERVICIO API PARA DEPARTAMENTOS
class DepartmentsApiService {
  static final Dio _dio = Dio();
  static String get baseUrl =>
      '${ServerConfig.instance.baseUrlFor('staff')}/departments';

  static Future<List<DepartmentModel>> listarDepartamentos() async {
    try {
      final response = await _dio.get(
        '$baseUrl/get_departments.php',
        queryParameters: {'include_stats': 'true'},
      );

      if (response.data['success']) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => DepartmentModel.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? 'Error desconocido');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<ApiResult<DepartmentModel>> crearDepartamento({
    required String name,
    String? description,
    int? managerId,
    bool isActive = true,
    int? createdBy,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/create_department.php',
        data: {
          'name': name,
          'description': description,
          'manager_id': managerId,
          'is_active': isActive,
          'created_by': createdBy,
        },
      );

      if (response.data['success']) {
        final departmentData = DepartmentModel.fromJson(response.data['data']);
        return ApiResult.success(
          data: departmentData,
          message: response.data['message'],
        );
      } else {
        return ApiResult.error(
          error: response.data['message'] ?? 'Error desconocido',
          errors: response.data['errors'],
        );
      }
    } catch (e) {
      return ApiResult.error(error: 'Error de conexión: $e');
    }
  }

  static Future<ApiResult<DepartmentModel>> actualizarDepartamento({
    required int departmentId,
    String? name,
    String? description,
    int? managerId,
    bool? isActive,
    int? updatedBy,
  }) async {
    try {
      final data = <String, dynamic>{'id': departmentId};

      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (managerId != null) data['manager_id'] = managerId;
      if (isActive != null) data['is_active'] = isActive;
      if (updatedBy != null) data['updated_by'] = updatedBy;

      final response = await _dio.put(
        '$baseUrl/update_department.php',
        data: data,
      );

      if (response.data['success']) {
        final departmentData = DepartmentModel.fromJson(response.data['data']);
        return ApiResult.success(
          data: departmentData,
          message: response.data['message'],
        );
      } else {
        return ApiResult.error(
          error: response.data['message'] ?? 'Error desconocido',
          errors: response.data['errors'],
        );
      }
    } catch (e) {
      return ApiResult.error(error: 'Error de conexión: $e');
    }
  }

  static Future<ApiResult<bool>> eliminarDepartamento({
    required int departmentId,
    String? reason,
    int? deletedBy,
  }) async {
    try {
      final response = await _dio.delete(
        '$baseUrl/delete_department.php',
        data: {'id': departmentId, 'reason': reason, 'deleted_by': deletedBy},
      );

      if (response.data['success']) {
        return ApiResult.success(data: true, message: response.data['message']);
      } else {
        return ApiResult.error(
          error: response.data['message'] ?? 'Error desconocido',
          errors: response.data['errors'],
        );
      }
    } catch (e) {
      return ApiResult.error(error: 'Error de conexión: $e');
    }
  }
}

// CLASE PARA RESULTADOS DE API
class ApiResult<T> {
  final bool isSuccess;
  final T? data;
  final String? message;
  final String? error;
  final Map<String, dynamic>? errors;

  ApiResult._({
    required this.isSuccess,
    this.data,
    this.message,
    this.error,
    this.errors,
  });

  factory ApiResult.success({T? data, String? message}) {
    return ApiResult._(isSuccess: true, data: data, message: message);
  }

  factory ApiResult.error({String? error, Map<String, dynamic>? errors}) {
    return ApiResult._(isSuccess: false, error: error, errors: errors);
  }
}

// WIDGET PRINCIPAL PARA CAMPO DEPARTAMENTO
class CampoDepartamento extends StatefulWidget {
  final int? departamentoId;
  final Function(int?) onChanged;
  final String? Function(int?)? validator;
  final bool enabled;
  // Permite mostrar todas las opciones automáticamente al enfocar
  final bool autoShowAll;

  const CampoDepartamento({
    super.key,
    required this.departamentoId,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.autoShowAll = false,
  });

  @override
  State<CampoDepartamento> createState() => _CampoDepartamentoState();
}

class _CampoDepartamentoState extends State<CampoDepartamento> {
  List<DepartmentModel> _departamentos = [];
  bool _isLoading = false;
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  int _expandClickCount = 0;
  bool _showAllOptions = false;
  Timer? _expandClickTimer;

  @override
  void initState() {
    super.initState();
    // Mostrar todas las opciones si se solicita
    _showAllOptions = widget.autoShowAll;
    _cargarDepartamentos();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void didUpdateWidget(covariant CampoDepartamento oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.departamentoId != widget.departamentoId) {
      _searchController.clear();
      _showAllOptions = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _expandClickTimer?.cancel();
    super.dispose();
  }

  void _handleSearchChange() {
    // Ya no ocultamos opciones por longitud
  }

  Future<void> _cargarDepartamentos() async {
    setState(() => _isLoading = true);
    try {
      final departamentos = await DepartmentsApiService.listarDepartamentos();
      setState(() => _departamentos = departamentos);
    } catch (e) {
      _mostrarError('Error cargando departamentos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  int? _getValidValue() {
    if (widget.departamentoId == null) return null;
    final departamentosConEsteId =
        _departamentos
            .where((d) => d.id == widget.departamentoId && d.isActive)
            .toList();
    return departamentosConEsteId.length == 1 ? widget.departamentoId : null;
  }

  DepartmentModel? get _departamentoSeleccionado {
    if (widget.departamentoId == null) return null;
    return _departamentos.firstWhere(
      (d) => d.id == widget.departamentoId,
      orElse:
          () => DepartmentModel(
            id: 0,
            name: 'Desconocido',
            isActive: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            hasManager: false,
          ),
    );
  }
  Widget _buildSuffixButtons() {
    final departamento = _departamentoSeleccionado;
    final hayDepartamentoSeleccionado =
        departamento != null && departamento.id > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón para expandir/contraer
        IconButton(
          icon: Icon(
            PhosphorIcons.caretDown(),
            color: Theme.of(context).primaryColor,
          ),
          onPressed: _handleExpandClick,
          tooltip: 'Ver opciones',
        ),

        // Botón de editar (solo visible si hay selección)
        if (hayDepartamentoSeleccionado && widget.enabled)
          IconButton(
            icon: Icon(PhosphorIcons.pencilSimple(), color: Theme.of(context).primaryColor),
            onPressed: () => _showDepartamentoFormDialog(departamento),
            tooltip: 'Editar departamento',
          ),

        // Botón de eliminar (solo visible si hay selección y se puede eliminar)
        if (hayDepartamentoSeleccionado &&
            widget.enabled &&
            departamento.canBeDeleted)
          IconButton(
            icon: Icon(PhosphorIcons.trash(), color: Colors.red),
            onPressed: () => _eliminarDepartamento(departamento),
            tooltip: 'Eliminar departamento',
          ),

        // Botón de agregar
        if (widget.enabled)
          IconButton(
            icon: Icon(PhosphorIcons.plus(), color: Colors.green),
            onPressed: () => _showDepartamentoFormDialog(),
            tooltip: 'Nuevo departamento',
          ),
      ],
    );
  }

  void _handleExpandClick() {
    _expandClickCount++;
    _expandClickTimer?.cancel();
    _expandClickTimer = Timer(const Duration(seconds: 1), () {
      _expandClickCount = 0;
    });

    if (_expandClickCount >= 3) {
      setState(() {
        _showAllOptions = true;
        _searchFocusNode.requestFocus();
      });
    } else {
      setState(() => _showAllOptions = !_showAllOptions);
      if (_showAllOptions) _searchFocusNode.requestFocus();
    }
  }

  Widget _buildSearchableDropdown() {
    final departamentosUnicos = <int, DepartmentModel>{};
    for (var departamento in _departamentos) {
      if (departamento.isActive && departamento.id > 0) {
        departamentosUnicos[departamento.id] = departamento;
      }
    }

    return SearchableDropdownDepartment(
      value: _getValidValue(),
      items: departamentosUnicos.values.toList(),
      onChanged:
          widget.enabled && !_isLoading
              ? (value) {
                _searchController.clear();
                _showAllOptions = false;
                widget.onChanged(value);
              }
              : null,
      focusNode: _searchFocusNode,
      searchController: _searchController,
      isLoading: _isLoading,
      suffixButtons: _buildSuffixButtons(),
      prefixIcon: Icon(
        PhosphorIcons.buildings(),
        color: Theme.of(context).primaryColor,
      ),
      labelText: 'Departamento',
      validator: widget.validator,
      showAllOptions: _showAllOptions,
      onShowAllOptionsChanged: (show) => setState(() => _showAllOptions = show),
    );
  }

  Future<void> _eliminarDepartamento(DepartmentModel departamento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(PhosphorIcons.warning(), color: Colors.orange.shade600),
                const SizedBox(width: 8),
                const Text('Eliminar Departamento'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Está seguro de eliminar "${departamento.name}"?'),
                const SizedBox(height: 8),
                if (departamento.activeEmployees > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚠️ Este departamento tiene ${departamento.activeEmployees} empleado(s) activo(s).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚠️ Esta acción no se puede deshacer.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              if (departamento.canBeDeleted)
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Eliminar'),
                ),
            ],
          ),
    );

    if (confirmar != true || !departamento.canBeDeleted) return;

    try {
      final resultado = await DepartmentsApiService.eliminarDepartamento(
        departmentId: departamento.id,
        reason: 'Eliminado desde la interfaz de usuario',
      );

      if (resultado.isSuccess) {
        if (widget.departamentoId == departamento.id) {
          widget.onChanged(null);
        }
        await _cargarDepartamentos();
        _searchController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado.message ?? 'Departamento eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _mostrarError(
          resultado.error ?? 'Error desconocido al eliminar departamento',
        );
      }
    } catch (e) {
      _mostrarError('Error de conexión: $e');
    }
  }

  Future<void> _showDepartamentoFormDialog([DepartmentModel? departamento]) async {
    final result = await showDialog<DepartmentModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DepartamentoFormDialog(departamentoEditando: departamento),
    );

    if (result != null) {
      await _cargarDepartamentos();
      widget.onChanged(result.id);
      _searchController.clear();
      setState(() => _showAllOptions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
      child: _buildSearchableDropdown(),
    );
  }
}

class _DepartamentoFormDialog extends StatefulWidget {
  final DepartmentModel? departamentoEditando;

  const _DepartamentoFormDialog({this.departamentoEditando});

  @override
  State<_DepartamentoFormDialog> createState() => _DepartamentoFormDialogState();
}

class _DepartamentoFormDialogState extends State<_DepartamentoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;
  Map<String, String> _backendErrors = {};

  @override
  void initState() {
    super.initState();
    if (widget.departamentoEditando != null) {
      _nombreController.text = widget.departamentoEditando!.name;
      _descripcionController.text = widget.departamentoEditando!.description ?? '';
      _isActive = widget.departamentoEditando!.isActive;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Map<String, String> _parseBackendErrors(Map<String, dynamic>? rawErrors) {
    if (rawErrors == null) return {};
    final parsed = <String, String>{};
    rawErrors.forEach((key, value) {
      if (value is String) {
        parsed[key] = value;
      } else if (value is List && value.isNotEmpty) {
        parsed[key] = value.first.toString();
      } else {
        parsed[key] = value.toString();
      }
    });
    return parsed;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _backendErrors.clear();
    });

    try {
      final nombre = _nombreController.text.trim();
      final descripcion = _descripcionController.text.trim();

      ApiResult<DepartmentModel> resultado;

      if (widget.departamentoEditando == null) {
        resultado = await DepartmentsApiService.crearDepartamento(
          name: nombre,
          description: descripcion.isNotEmpty ? descripcion : null,
          isActive: _isActive,
        );
      } else {
        resultado = await DepartmentsApiService.actualizarDepartamento(
          departmentId: widget.departamentoEditando!.id,
          name: nombre,
          description: descripcion.isNotEmpty ? descripcion : null,
          isActive: _isActive,
        );
      }

      if (resultado.isSuccess && resultado.data != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado.message ?? 'Operación exitosa'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(resultado.data);
        }
      } else {
        if (mounted) {
          setState(() {
            _backendErrors = _parseBackendErrors(resultado.errors);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado.error ?? 'Error desconocido'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.departamentoEditando != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isEditing ? PhosphorIcons.pencilSimple() : PhosphorIcons.briefcase(),
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Editar Departamento' : 'Nuevo Departamento',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del departamento *',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(PhosphorIcons.buildings()),
                    errorText: _backendErrors['name'],
                  ),
                  enabled: !_isSaving,
                  onChanged: (_) {
                    if (_backendErrors.containsKey('name')) {
                      setState(() => _backendErrors.remove('name'));
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    if (value.trim().length < 2) {
                      return 'El nombre debe tener al menos 2 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionController,
                  decoration: InputDecoration(
                    labelText: 'Descripción',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(PhosphorIcons.fileText()),
                    helperText: 'Opcional',
                    errorText: _backendErrors['description'],
                  ),
                  enabled: !_isSaving,
                  maxLines: 2,
                  onChanged: (_) {
                    if (_backendErrors.containsKey('description')) {
                      setState(() => _backendErrors.remove('description'));
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _isActive,
                      onChanged: _isSaving ? null : (v) => setState(() => _isActive = v ?? true),
                    ),
                    const Text('Departamento activo'),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancelar'),
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Guardando...' : (isEditing ? 'Actualizar' : 'Guardar')),
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
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
}


// DROPDOWN SEARCHABLE PARA DEPARTAMENTOS
class SearchableDropdownDepartment extends StatefulWidget {
  final int? value;
  final List<DepartmentModel> items;
  final ValueChanged<int?>? onChanged;
  final FocusNode focusNode;
  final TextEditingController searchController;
  final bool isLoading;
  final Widget suffixButtons;
  final Widget prefixIcon;
  final String labelText;
  final String? Function(int?)? validator;
  final bool showAllOptions;
  final ValueChanged<bool>? onShowAllOptionsChanged;

  const SearchableDropdownDepartment({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.focusNode,
    required this.searchController,
    required this.isLoading,
    required this.suffixButtons,
    required this.prefixIcon,
    required this.labelText,
    this.validator,
    this.showAllOptions = false,
    this.onShowAllOptionsChanged,
  });

  @override
  State<SearchableDropdownDepartment> createState() =>
      _SearchableDropdownDepartmentState();
}

class _SearchableDropdownDepartmentState
    extends State<SearchableDropdownDepartment> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _showOptions = false;
  bool _isProcessingSelection = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
    widget.searchController.addListener(_handleSearchChange);
    // Removido: auto-apertura del overlay en el primer render para evitar overlays simultáneos
  }

  @override
  void didUpdateWidget(covariant SearchableDropdownDepartment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showAllOptions != oldWidget.showAllOptions) {
      if (widget.showAllOptions) {
        _showOptionsOverlay();
      } else if (!_isProcessingSelection) {
        _hideOptionsOverlay();
      }
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    widget.searchController.removeListener(_handleSearchChange);
    _hideOptionsOverlay(isDisposing: true);
    super.dispose();
  }

  void _handleFocusChange() {
    if (widget.focusNode.hasFocus) {
      // Mostrar overlay siempre que tenga foco
      _showOptionsOverlay();
    } else if (!_isProcessingSelection) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!_isProcessingSelection && mounted) {
          _hideOptionsOverlay();
        }
      });
    }
  }

  void _handleSearchChange() {
    if (widget.focusNode.hasFocus) {
      _showOptionsOverlay();
    } else if (!widget.showAllOptions && !_isProcessingSelection) {
      _hideOptionsOverlay();
    }
  }

  void _showOptionsOverlay() {
    if (_overlayEntry != null || _isProcessingSelection) return;

    // Calcular ancho del campo para limitar el overlay
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final double fieldWidth =
        box?.size.width ?? MediaQuery.of(context).size.width * 0.9;

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            width: fieldWidth,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 48),
              child: Material(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: 300,
                    maxWidth: fieldWidth,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildOptionsList(),
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showOptions = true);
  }

  void _hideOptionsOverlay({bool isDisposing = false}) {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;

      if (isDisposing) return;

      // Diferir notificaciones y setState al próximo frame para evitar errores durante build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _showOptions = false);
        if (widget.onShowAllOptionsChanged != null) {
          widget.onShowAllOptionsChanged!(false);
        }
      });
    }
  }

  List<DepartmentModel> _getFilteredItems() {
    if (widget.showAllOptions) return widget.items;

    final searchText = widget.searchController.text.toLowerCase();
    // if (searchText.length < 3) return []; -> Permitir búsqueda inmediata

    return widget.items
        .where((d) => d.descripcion.toLowerCase().contains(searchText))
        .toList();
  }

  Widget _buildOptionsList() {
    final filteredItems = _getFilteredItems();

    if (widget.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (filteredItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.showAllOptions
              ? 'No hay departamentos disponibles'
              : 'No se encontraron resultados',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final departamento = filteredItems[index];
        return _buildOptionItem(departamento);
      },
    );
  }

  Widget _buildOptionItem(DepartmentModel departamento) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleOptionSelection(departamento),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                departamento.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (departamento.description != null)
                Text(
                  departamento.description!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              if (departamento.hasManager)
                Text(
                  'Manager: ${departamento.managerName}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleOptionSelection(DepartmentModel departamento) async {
    if (_isProcessingSelection) return;

    setState(() => _isProcessingSelection = true);

    try {
      if (widget.onChanged != null) {
        widget.onChanged!(departamento.id);
      }

      await Future.delayed(const Duration(milliseconds: 50));
      _hideOptionsOverlay();
    } finally {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _isProcessingSelection = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final departamentoSeleccionado =
        widget.value != null
            ? widget.items.firstWhere(
              (d) => d.id == widget.value,
              orElse:
                  () => DepartmentModel(
                    id: 0,
                    name: 'Seleccione un departamento',
                    isActive: true,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    hasManager: false,
                  ),
            )
            : null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: widget.searchController,
            focusNode: widget.focusNode,
            decoration: InputDecoration(
              labelText: widget.labelText,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixButtons,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            readOnly: widget.onChanged == null,
            validator:
                widget.validator != null
                    ? (_) => widget.validator!(widget.value)
                    : null,
          ),
          if (widget.value != null && !_showOptions)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8, right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    departamentoSeleccionado?.name ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (departamentoSeleccionado?.description != null)
                    Text(
                      departamentoSeleccionado!.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  if (departamentoSeleccionado?.hasManager == true)
                    Text(
                      'Manager: ${departamentoSeleccionado!.managerName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade600,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
