import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:dio/dio.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/core/utils/currency_utils.dart';
import 'package:infoapp/widgets/currency_input_formatter.dart';

// MODELO DE POSICIÓN
class PositionModel {
  final int id;
  final String title;
  final String? description;
  final int departmentId;
  final String? departmentName;
  final double? minSalary;
  final double? maxSalary;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasSalaryRange;
  final String? salaryRangeText;
  final int totalEmployees;
  final int activeEmployees;
  final int inactiveEmployees;

  PositionModel({
    required this.id,
    required this.title,
    this.description,
    required this.departmentId,
    this.departmentName,
    this.minSalary,
    this.maxSalary,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.totalEmployees = 0,
    this.activeEmployees = 0,
    this.inactiveEmployees = 0,
  }) : hasSalaryRange = (minSalary != null && maxSalary != null),
       salaryRangeText =
           (minSalary != null && maxSalary != null)
               ? '\$${CurrencyUtils.format(minSalary)} - \$${CurrencyUtils.format(maxSalary)}'
               : null;

  factory PositionModel.fromJson(Map<String, dynamic> json) {
    return PositionModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      departmentId: json['department_id'] ?? 0,
      departmentName: json['department_name'],
      minSalary:
          json['min_salary'] != null
              ? double.tryParse(json['min_salary'].toString())
              : null,
      maxSalary:
          json['max_salary'] != null
              ? double.tryParse(json['max_salary'].toString())
              : null,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      totalEmployees: json['total_employees'] ?? 0,
      activeEmployees: json['active_employees'] ?? 0,
      inactiveEmployees: json['inactive_employees'] ?? 0,
    );
  }

  String get descripcion => title;

  String get displayText {
    if (departmentName != null) {
      return '$title ($departmentName)';
    }
    return title;
  }

  String get fullDisplayText {
    List<String> parts = [title];
    if (description != null && description!.isNotEmpty) {
      parts.add(description!);
    }
    if (salaryRangeText != null) {
      parts.add(salaryRangeText!);
    }
    return parts.join(' - ');
  }

  bool get canBeDeleted => activeEmployees == 0;
}

// SERVICIO API PARA POSICIONES
class PositionsApiService {
  static final Dio _dio = Dio();
  static String get baseUrl =>
      '${ServerConfig.instance.baseUrlFor('staff')}/positions';

  static Future<List<PositionModel>> listarPosiciones({
    int? departmentId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'include_stats': 'true'};
      if (departmentId != null) {
        queryParams['department_id'] = departmentId;
      }

      final response = await _dio.get(
        '$baseUrl/get_positions.php',
        queryParameters: queryParams,
      );

      if (response.data['success']) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => PositionModel.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? 'Error desconocido');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<ApiResultPosition<PositionModel>> crearPosicion({
    required String title,
    String? description,
    required int departmentId,
    double? minSalary,
    double? maxSalary,
    bool isActive = true,
    int? createdBy,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/create_position.php',
        data: {
          'title': title,
          'description': description,
          'department_id': departmentId,
          'min_salary': minSalary,
          'max_salary': maxSalary,
          'is_active': isActive,
          'created_by': createdBy,
        },
      );

      if (response.data['success']) {
        final positionData = PositionModel.fromJson(response.data['data']);
        return ApiResultPosition.success(
          data: positionData,
          message: response.data['message'],
        );
      } else {
        return ApiResultPosition.error(
          error: response.data['message'] ?? 'Error desconocido',
          errors: response.data['errors'],
        );
      }
    } catch (e) {
      return ApiResultPosition.error(error: 'Error de conexión: $e');
    }
  }

  static Future<ApiResultPosition<PositionModel>> actualizarPosicion({
    required int positionId,
    String? title,
    String? description,
    int? departmentId,
    double? minSalary,
    double? maxSalary,
    bool? isActive,
    int? updatedBy,
  }) async {
    try {
      final data = <String, dynamic>{'id': positionId};

      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (departmentId != null) data['department_id'] = departmentId;
      if (minSalary != null) data['min_salary'] = minSalary;
      if (maxSalary != null) data['max_salary'] = maxSalary;
      if (isActive != null) data['is_active'] = isActive;
      if (updatedBy != null) data['updated_by'] = updatedBy;

      final response = await _dio.put(
        '$baseUrl/update_position.php',
        data: data,
      );

      if (response.data['success']) {
        final positionData = PositionModel.fromJson(response.data['data']);
        return ApiResultPosition.success(
          data: positionData,
          message: response.data['message'],
        );
      } else {
        return ApiResultPosition.error(
          error: response.data['message'] ?? 'Error desconocido',
          errors: response.data['errors'],
        );
      }
    } catch (e) {
      return ApiResultPosition.error(error: 'Error de conexión: $e');
    }
  }

  static Future<ApiResultPosition<bool>> eliminarPosicion({
    required int positionId,
    String? reason,
    int? deletedBy,
  }) async {
    try {
      final response = await _dio.delete(
        '$baseUrl/delete_position.php',
        data: {'id': positionId, 'reason': reason, 'deleted_by': deletedBy},
      );

      if (response.data['success']) {
        return ApiResultPosition.success(
          data: true,
          message: response.data['message'],
        );
      } else {
        return ApiResultPosition.error(
          error: response.data['message'] ?? 'Error desconocido',
          errors: response.data['errors'],
        );
      }
    } catch (e) {
      return ApiResultPosition.error(error: 'Error de conexión: $e');
    }
  }
}

// CLASE PARA RESULTADOS DE API
class ApiResultPosition<T> {
  final bool isSuccess;
  final T? data;
  final String? message;
  final String? error;
  final Map<String, dynamic>? errors;

  ApiResultPosition._({
    required this.isSuccess,
    this.data,
    this.message,
    this.error,
    this.errors,
  });

  factory ApiResultPosition.success({T? data, String? message}) {
    return ApiResultPosition._(isSuccess: true, data: data, message: message);
  }

  factory ApiResultPosition.error({
    String? error,
    Map<String, dynamic>? errors,
  }) {
    return ApiResultPosition._(isSuccess: false, error: error, errors: errors);
  }
}

// WIDGET PRINCIPAL PARA CAMPO POSICIÓN
class CampoPosition extends StatefulWidget {
  final int? posicionId;
  final int?
  departamentoId; // Requerido para filtrar posiciones por departamento
  final Function(int?) onChanged;
  final String? Function(int?)? validator;
  final bool enabled;
  // Permite mostrar todas las opciones automáticamente al enfocar (si hay departamento)
  final bool autoShowAll;

  const CampoPosition({
    super.key,
    required this.posicionId,
    this.departamentoId,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.autoShowAll = false,
  });

  @override
  State<CampoPosition> createState() => _CampoPositionState();
}

class _CampoPositionState extends State<CampoPosition> {
  List<PositionModel> _posiciones = [];
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
    _cargarPosiciones();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void didUpdateWidget(covariant CampoPosition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.posicionId != widget.posicionId) {
      _searchController.clear();
      _showAllOptions = false;
    }
    // Si cambió el departamento, recargar posiciones
    if (oldWidget.departamentoId != widget.departamentoId) {
      _cargarPosiciones();
      // Limpiar selección si cambió el departamento
      if (widget.departamentoId != oldWidget.departamentoId &&
          widget.posicionId != null) {
        widget.onChanged(null);
      }
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

  Future<void> _cargarPosiciones() async {
    if (widget.departamentoId == null) {
      setState(() => _posiciones = []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final posiciones = await PositionsApiService.listarPosiciones(
        departmentId: widget.departamentoId,
      );
      setState(() => _posiciones = posiciones);
    } catch (e) {
      _mostrarError('Error cargando posiciones: $e');
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
    if (widget.posicionId == null) return null;
    final posicionesConEsteId =
        _posiciones
            .where((p) => p.id == widget.posicionId && p.isActive)
            .toList();
    return posicionesConEsteId.length == 1 ? widget.posicionId : null;
  }

  PositionModel? get _posicionSeleccionada {
    if (widget.posicionId == null) return null;
    return _posiciones.firstWhere(
      (p) => p.id == widget.posicionId,
      orElse:
          () => PositionModel(
            id: 0,
            title: 'Desconocido',
            departmentId: 0,
            isActive: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
    );
  }

  Widget _buildSuffixButtons() {
    final posicion = _posicionSeleccionada;
    final hayPosicionSeleccionada = posicion != null && posicion.id > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón para expandir/contraer
        IconButton(
          icon: Icon(
            PhosphorIcons.caretDown(),
            color: Theme.of(context).primaryColor,
          ),
          onPressed: widget.departamentoId != null ? _handleExpandClick : null,
          tooltip: 'Ver opciones',
        ),

        // Botón de editar (solo visible si hay selección)
        if (hayPosicionSeleccionada &&
            widget.enabled &&
            widget.departamentoId != null)
          IconButton(
            icon: Icon(PhosphorIcons.pencilSimple(), color: Theme.of(context).primaryColor),
            onPressed: () => _showPosicionFormDialog(posicion),
            tooltip: 'Editar cargo',
          ),

        // Botón de eliminar (solo visible si hay selección y se puede eliminar)
        if (hayPosicionSeleccionada &&
            widget.enabled &&
            widget.departamentoId != null &&
            posicion.canBeDeleted)
          IconButton(
            icon: Icon(PhosphorIcons.trash(), color: Colors.red),
            onPressed: () => _eliminarPosicion(posicion),
            tooltip: 'Eliminar cargo',
          ),

        // Botón de agregar
        if (widget.enabled && widget.departamentoId != null)
          IconButton(
            icon: Icon(PhosphorIcons.plus(), color: Colors.green),
            onPressed: () => _showPosicionFormDialog(),
            tooltip: 'Nuevo cargo',
          ),
      ],
    );
  }

  void _handleExpandClick() {
    if (widget.departamentoId == null) {
      _mostrarError('Selecciona un departamento primero');
      return;
    }

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
    final posicionesUnicas = <int, PositionModel>{};
    for (var posicion in _posiciones) {
      if (posicion.isActive && posicion.id > 0) {
        posicionesUnicas[posicion.id] = posicion;
      }
    }

    return SearchableDropdownPosition(
      value: _getValidValue(),
      items: posicionesUnicas.values.toList(),
      onChanged:
          widget.enabled && !_isLoading && widget.departamentoId != null
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
      prefixIcon: Icon(PhosphorIcons.briefcase(), color: Theme.of(context).primaryColor),
      labelText: 'Cargo',
      validator: widget.validator,
      showAllOptions: _showAllOptions,
      onShowAllOptionsChanged: (show) => setState(() => _showAllOptions = show),
      departamentoId: widget.departamentoId,
    );
  }

  Future<void> _showPosicionFormDialog([PositionModel? posicion]) async {
    final result = await showDialog<PositionModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PosicionFormDialog(
        posicionEditando: posicion,
        departamentoId: widget.departamentoId!,
      ),
    );

    if (result != null) {
      await _cargarPosiciones();
      widget.onChanged(result.id);
      _searchController.clear();
      setState(() => _showAllOptions = false);
    }
  }

  Future<void> _eliminarPosicion(PositionModel posicion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                const Text('Eliminar Cargo'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Está seguro de eliminar "${posicion.title}"?'),
                const SizedBox(height: 8),
                if (posicion.activeEmployees > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚠️ Este cargo tiene ${posicion.activeEmployees} empleado(s) activo(s).',
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
              if (posicion.canBeDeleted)
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

    if (confirmar != true || !posicion.canBeDeleted) return;

    try {
      final resultado = await PositionsApiService.eliminarPosicion(
        positionId: posicion.id,
        reason: 'Eliminado desde la interfaz de usuario',
      );

      if (resultado.isSuccess) {
        if (widget.posicionId == posicion.id) {
          widget.onChanged(null);
        }
        await _cargarPosiciones();
        _searchController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado.message ?? 'Cargo eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _mostrarError(
          resultado.error ?? 'Error desconocido al eliminar cargo',
        );
      }
    } catch (e) {
      _mostrarError('Error de conexión: $e');
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

class _PosicionFormDialog extends StatefulWidget {
  final PositionModel? posicionEditando;
  final int departamentoId;

  const _PosicionFormDialog({
    this.posicionEditando,
    required this.departamentoId,
  });

  @override
  State<_PosicionFormDialog> createState() => _PosicionFormDialogState();
}

class _PosicionFormDialogState extends State<_PosicionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _salarioMinController = TextEditingController();
  final _salarioMaxController = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;
  Map<String, String> _backendErrors = {};

  @override
  void initState() {
    super.initState();
    if (widget.posicionEditando != null) {
      _tituloController.text = widget.posicionEditando!.title;
      _descripcionController.text = widget.posicionEditando!.description ?? '';
      _salarioMinController.text = widget.posicionEditando!.minSalary != null ? CurrencyUtils.format(widget.posicionEditando!.minSalary) : '';
      _salarioMaxController.text = widget.posicionEditando!.maxSalary != null ? CurrencyUtils.format(widget.posicionEditando!.maxSalary) : '';
      _isActive = widget.posicionEditando!.isActive;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _salarioMinController.dispose();
    _salarioMaxController.dispose();
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
      final titulo = _tituloController.text.trim();
      final descripcion = _descripcionController.text.trim();
      final salarioMin = _salarioMinController.text.isNotEmpty
          ? CurrencyUtils.parse(_salarioMinController.text)
          : null;
      final salarioMax = _salarioMaxController.text.isNotEmpty
          ? CurrencyUtils.parse(_salarioMaxController.text)
          : null;

      ApiResultPosition<PositionModel> resultado;

      if (widget.posicionEditando == null) {
        resultado = await PositionsApiService.crearPosicion(
          title: titulo,
          description: descripcion.isNotEmpty ? descripcion : null,
          departmentId: widget.departamentoId,
          minSalary: salarioMin,
          maxSalary: salarioMax,
          isActive: _isActive,
        );
      } else {
        resultado = await PositionsApiService.actualizarPosicion(
          positionId: widget.posicionEditando!.id,
          title: titulo,
          description: descripcion.isNotEmpty ? descripcion : null,
          minSalary: salarioMin,
          maxSalary: salarioMax,
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
    final isEditing = widget.posicionEditando != null;

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
                      isEditing ? 'Editar Cargo' : 'Nuevo Cargo',
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
                  controller: _tituloController,
                  decoration: InputDecoration(
                    labelText: 'Título del cargo *',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(PhosphorIcons.briefcase()),
                    errorText: _backendErrors['title'],
                  ),
                  enabled: !_isSaving,
                  onChanged: (_) {
                    if (_backendErrors.containsKey('title')) {
                      setState(() => _backendErrors.remove('title'));
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El título es obligatorio';
                    }
                    if (value.trim().length < 2) {
                      return 'El título debe tener al menos 2 caracteres';
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
                    Expanded(
                      child: TextFormField(
                        controller: _salarioMinController,
                        decoration: InputDecoration(
                          labelText: 'Salario Mínimo',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(PhosphorIcons.currencyDollar()),
                          prefixText: '\$ ',
                          errorText: _backendErrors['min_salary'],
                        ),
                        enabled: !_isSaving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(),
                        ],
                        onChanged: (_) {
                          if (_backendErrors.containsKey('min_salary')) {
                            setState(() => _backendErrors.remove('min_salary'));
                          }
                        },
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final salario = CurrencyUtils.parse(value);
                            if (salario < 0) {
                              return 'Salario inválido';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _salarioMaxController,
                        decoration: InputDecoration(
                          labelText: 'Salario Máximo',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(PhosphorIcons.currencyDollar()),
                          prefixText: '\$ ',
                          errorText: _backendErrors['max_salary'],
                        ),
                        enabled: !_isSaving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(),
                        ],
                        onChanged: (_) {
                          if (_backendErrors.containsKey('max_salary')) {
                            setState(() => _backendErrors.remove('max_salary'));
                          }
                        },
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final salarioMax = CurrencyUtils.parse(value);
                            if (salarioMax < 0) {
                              return 'Salario inválido';
                            }
                            final salarioMin = _salarioMinController.text.isNotEmpty
                                ? CurrencyUtils.parse(_salarioMinController.text)
                                : null;
                            if (salarioMin != null && salarioMax < salarioMin) {
                              return 'Debe ser >= salario mín.';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _isActive,
                      onChanged: _isSaving ? null : (v) => setState(() => _isActive = v ?? true),
                    ),
                    const Text('Cargo activo'),
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

// DROPDOWN SEARCHABLE PARA POSICIONES
class SearchableDropdownPosition extends StatefulWidget {
  final int? value;
  final List<PositionModel> items;
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
  final int? departamentoId;

  const SearchableDropdownPosition({
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
    this.departamentoId,
  });

  @override
  State<SearchableDropdownPosition> createState() =>
      _SearchableDropdownPositionState();
}

class _SearchableDropdownPositionState
    extends State<SearchableDropdownPosition> {
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
  void didUpdateWidget(covariant SearchableDropdownPosition oldWidget) {
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
    if (widget.focusNode.hasFocus && widget.departamentoId != null) {
      _showOptionsOverlay();
    } else if (!widget.showAllOptions && !_isProcessingSelection) {
      _hideOptionsOverlay();
    }
  }

  void _showOptionsOverlay() {
    if (_overlayEntry != null || _isProcessingSelection) {
      return;
    }

    // Calcular ancho del campo para limitar el overlay
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final double fieldWidth =
        box?.size.width ?? MediaQuery.of(context).size.width * 0.9;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
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
              constraints:
                  BoxConstraints(maxHeight: 300, maxWidth: fieldWidth),
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

  List<PositionModel> _getFilteredItems() {
    if (widget.showAllOptions) return widget.items;

    final searchText = widget.searchController.text.toLowerCase();
    // if (searchText.length < 3) return []; -> Permitir búsqueda inmediata

    return widget.items
        .where(
          (p) =>
              p.title.toLowerCase().contains(searchText) ||
              (p.description?.toLowerCase().contains(searchText) ?? false),
        )
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
              ? 'No hay cargos disponibles para este departamento'
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
        final posicion = filteredItems[index];
        return _buildOptionItem(posicion);
      },
    );
  }

  Widget _buildOptionItem(PositionModel posicion) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleOptionSelection(posicion),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                posicion.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (posicion.description != null)
                Text(
                  posicion.description!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              if (posicion.salaryRangeText != null)
                Text(
                  'Rango salarial: ${posicion.salaryRangeText}',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                ),
              if (posicion.totalEmployees > 0)
                Text(
                  '${posicion.activeEmployees} empleado(s) activo(s)',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleOptionSelection(PositionModel posicion) async {
    if (_isProcessingSelection) return;

    setState(() => _isProcessingSelection = true);

    try {
      if (widget.onChanged != null) {
        widget.onChanged!(posicion.id);
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
    final posicionSeleccionada =
        widget.value != null
            ? widget.items.firstWhere(
              (p) => p.id == widget.value,
              orElse:
                  () => PositionModel(
                    id: 0,
                    title:
                        widget.departamentoId == null
                            ? 'Seleccione un departamento primero'
                            : 'Seleccione un cargo',
                    departmentId: 0,
                    isActive: true,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
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
                    posicionSeleccionada?.title ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (posicionSeleccionada?.description != null)
                    Text(
                      posicionSeleccionada!.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  if (posicionSeleccionada?.salaryRangeText != null)
                    Text(
                      'Rango salarial: ${posicionSeleccionada!.salaryRangeText}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade600,
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
