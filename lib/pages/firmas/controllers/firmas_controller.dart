import 'package:flutter/material.dart';
import '../models/firma_model.dart';
import '../services/firmas_service.dart';

class FirmasController extends ChangeNotifier {
  // ❌ REMOVER: Ya no necesitas instancia
  // final FirmasService _firmasService = FirmasService();

  // Estado de carga
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Lista de firmas
  List<FirmaModel> _firmas = [];
  List<FirmaModel> get firmas => _firmas;

  // Firma actual (para edición/visualización)
  FirmaModel? _firmaActual;
  FirmaModel? get firmaActual => _firmaActual;

  // Estado del formulario de captura
  int? _servicioSeleccionado;
  int? _staffSeleccionado;
  int? _funcionarioSeleccionado;
  String? _firmaStaffBase64;
  String? _firmaFuncionarioBase64;
  String? _notaEntrega;
  String? _notaRecepcion;

  // Getters del formulario
  int? get servicioSeleccionado => _servicioSeleccionado;
  int? get staffSeleccionado => _staffSeleccionado;
  int? get funcionarioSeleccionado => _funcionarioSeleccionado;
  String? get firmaStaffBase64 => _firmaStaffBase64;
  String? get firmaFuncionarioBase64 => _firmaFuncionarioBase64;
  String? get notaEntrega => _notaEntrega;
  String? get notaRecepcion => _notaRecepcion;

  // Paginación
  int _currentPage = 0;
  int _totalRegistros = 0;
  final int _pageSize = 50;

  int get currentPage => _currentPage;
  int get totalRegistros => _totalRegistros;
  int get pageSize => _pageSize;
  int get totalPages => (_totalRegistros / _pageSize).ceil();

  // Mensajes de error
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 1. Listar firmas con filtros opcionales
  Future<void> listarFirmas({
    int? idServicio,
    String? fechaDesde,
    String? fechaHasta,
    int? page,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final pageToLoad = page ?? _currentPage;
      final offset = pageToLoad * _pageSize;

      // ✅ CAMBIO: Usar método estático
      final result = await FirmasService.listarFirmas(
        idServicio: idServicio,
        fechaDesde: fechaDesde,
        fechaHasta: fechaHasta,
        limite: _pageSize,
        offset: offset,
      );

      if (result['success'] == true) {
        _firmas = result['firmas'] as List<FirmaModel>;
        _totalRegistros = result['pagination']['total'] as int;
        _currentPage = pageToLoad;
      } else {
        _errorMessage = result['message'] as String;
        _firmas = [];
      }
    } catch (e) {
      _errorMessage = 'Error al cargar firmas: $e';
      _firmas = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Obtener firma por ID
  Future<bool> obtenerFirma(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ✅ CAMBIO: Usar método estático
      final result = await FirmasService.obtenerFirma(id);

      if (result['success'] == true) {
        return true;
      } else {
        _errorMessage = result['message'] as String;
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al obtener firma: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. Obtener firmas por servicio
  Future<List<FirmaModel>> obtenerFirmasPorServicio(int idServicio) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ✅ CAMBIO: Usar método estático
      // 🔎 Debug: log de entrada
      // ignore: avoid_print
      print('[FirmasController] obtenerFirmasPorServicio(idServicio=$idServicio)');
      final result = await FirmasService.obtenerFirmasPorServicio(idServicio);

      if (result['success'] == true) {
        final firmas = result['firmas'] as List<FirmaModel>;
        // ignore: avoid_print
        print('[FirmasController] OK - totalFirmas=${result['totalFirmas']}');
        return firmas;
      } else {
        _errorMessage = result['message'] as String;
        // ignore: avoid_print
        print('[FirmasController] Error: $_errorMessage');
        return [];
      }
    } catch (e) {
      _errorMessage = 'Error al obtener firmas del servicio: $e';
      // ignore: avoid_print
      print('[FirmasController] Exception: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 4. Setters para el formulario
  void setServicioSeleccionado(int? id) {
    _servicioSeleccionado = id;
    notifyListeners();
  }

  void setStaffSeleccionado(int? id) {
    _staffSeleccionado = id;
    notifyListeners();
  }

  void setFuncionarioSeleccionado(int? id) {
    _funcionarioSeleccionado = id;
    notifyListeners();
  }

  void setFirmaStaff(String? base64) {
    _firmaStaffBase64 = base64;
    notifyListeners();
  }

  void setFirmaFuncionario(String? base64) {
    _firmaFuncionarioBase64 = base64;
    notifyListeners();
  }

  void setNotaEntrega(String? nota) {
    _notaEntrega = nota;
    notifyListeners();
  }

  void setNotaRecepcion(String? nota) {
    _notaRecepcion = nota;
    notifyListeners();
  }

  // 5. Validar formulario
  Map<String, String> validarFormulario() {
    final errores = <String, String>{};

    if (_servicioSeleccionado == null) {
      errores['servicio'] = 'Debe seleccionar un servicio';
    }
    if (_staffSeleccionado == null) {
      errores['staff'] = 'Debe seleccionar el personal que entrega';
    }
    if (_funcionarioSeleccionado == null) {
      errores['funcionario'] = 'Debe seleccionar quien recibe';
    }
    if (_firmaStaffBase64 == null || _firmaStaffBase64!.isEmpty) {
      errores['firmaStaff'] = 'La firma del personal es obligatoria';
    }
    if (_firmaFuncionarioBase64 == null || _firmaFuncionarioBase64!.isEmpty) {
      errores['firmaFuncionario'] = 'La firma del funcionario es obligatoria';
    }

    return errores;
  }

  // 6. Crear firma
  Future<Map<String, dynamic>> crearFirma() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Validar formulario
      final errores = validarFormulario();
      if (errores.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': errores.values.first,
          'errores': errores,
        };
      }

      // Crear modelo
      final firma = FirmaModel(
        idServicio: _servicioSeleccionado!,
        idStaffEntrega: _staffSeleccionado!,
        idFuncionarioRecibe: _funcionarioSeleccionado!,
        firmaStaffBase64: _firmaStaffBase64!,
        firmaFuncionarioBase64: _firmaFuncionarioBase64!,
        notaEntrega: _notaEntrega,
        notaRecepcion: _notaRecepcion,
      );

      // ✅ CAMBIO: Usar método estático
      final result = await FirmasService.crearFirma(firma);

      if (result['success'] == true) {
        limpiarFormulario();
        // Recargar lista si es necesario
        await listarFirmas();
      } else {
        _errorMessage = result['message'] as String;
      }

      return result;
    } catch (e) {
      _errorMessage = 'Error al crear firma: $e';
      return {'success': false, 'message': _errorMessage};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 7. Eliminar firma
  Future<bool> eliminarFirma(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ✅ CAMBIO: Usar método estático
      final result = await FirmasService.eliminarFirma(id);

      if (result['success'] == true) {
        // Recargar lista
        await listarFirmas();
        return true;
      } else {
        _errorMessage = result['message'] as String;
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al eliminar firma: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 8. Limpiar formulario
  void limpiarFormulario() {
    _servicioSeleccionado = null;
    _staffSeleccionado = null;
    _funcionarioSeleccionado = null;
    _firmaStaffBase64 = null;
    _firmaFuncionarioBase64 = null;
    _notaEntrega = null;
    _notaRecepcion = null;
    _errorMessage = null;
    notifyListeners();
  }

  // 9. Navegación de páginas
  void siguientePagina() {
    if (_currentPage < totalPages - 1) {
      listarFirmas(page: _currentPage + 1);
    }
  }

  void paginaAnterior() {
    if (_currentPage > 0) {
      listarFirmas(page: _currentPage - 1);
    }
  }

  void irAPagina(int page) {
    if (page >= 0 && page < totalPages) {
      listarFirmas(page: page);
    }
  }

  // 10. Limpiar error
  void limpiarError() {
    _errorMessage = null;
    notifyListeners();
  }

}
