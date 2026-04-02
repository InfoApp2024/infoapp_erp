import 'package:flutter/foundation.dart';
import 'package:infoapp/pages/clientes/models/cliente_model.dart';
import 'package:infoapp/pages/clientes/models/ciudad_model.dart';
import 'package:infoapp/pages/clientes/models/departamento_model.dart';
import 'package:infoapp/pages/servicios/models/funcionario_model.dart';
import 'package:infoapp/pages/clientes/services/clientes_api_service.dart';
import 'package:infoapp/pages/clientes/services/ciudades_api_service.dart';
import 'package:infoapp/pages/servicios/services/servicios_api_service.dart';

class ClientesController extends ChangeNotifier {
  List<ClienteModel> _clientes = [];
  List<ClienteModel> get clientes => _clientes;

  List<CiudadModel> _ciudades = [];
  List<CiudadModel> get ciudades => _ciudades;

  List<DepartamentoModel> _departamentos = [];
  List<DepartamentoModel> get departamentos => _departamentos;

  List<FuncionarioModel> _funcionarios = [];
  List<FuncionarioModel> get funcionarios => _funcionarios;

  bool _loading = false;
  bool get loading => _loading;

  bool _loadingCiudades = false;
  bool get loadingCiudades => _loadingCiudades;

  bool _loadingFuncionarios = false;
  bool get loadingFuncionarios => _loadingFuncionarios;

  String _query = '';
  String get query => _query;

  bool _loadingDepartamentos = false;
  bool get loadingDepartamentos => _loadingDepartamentos;

  // Cargar clientes inicial
  Future<void> cargarClientes() async {
    _loading = true;
    notifyListeners();
    try {
      _clientes = await ClientesApiService.listarClientes(search: _query);
    } catch (e) {
      _clientes = [];
      if (kDebugMode) print('Error cargando clientes: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Búsqueda
  void setQuery(String q) {
    _query = q;
    // Debounce manual o simplemente recargar
    cargarClientes();
  }

  // Cargar lista de ciudades para selects
  Future<void> cargarCiudades({int? departamentoId}) async {
    _loadingCiudades = true;
    notifyListeners();
    try {
      _ciudades = await CiudadesApiService.listarCiudades(
        departamentoId: departamentoId,
      );
    } catch (e) {
      if (kDebugMode) print('Error cargando ciudades: $e');
    } finally {
      _loadingCiudades = false;
      notifyListeners();
    }
  }

  // Cargar lista de departamentos
  Future<void> cargarDepartamentos() async {
    if (_departamentos.isNotEmpty) return;
    _loadingDepartamentos = true;
    notifyListeners();
    try {
      _departamentos = await CiudadesApiService.listarDepartamentos();
    } catch (e) {
      if (kDebugMode) print('Error cargando departamentos: $e');
    } finally {
      _loadingDepartamentos = false;
      notifyListeners();
    }
  }

  // Refrescar ciudades forzosamente
  Future<void> refrescarCiudades() async {
    _ciudades.clear();
    await cargarCiudades();
  }

  // Obtener detalle completo
  Future<ClienteModel?> obtenerCliente(int id) async {
    final cliente = await ClientesApiService.obtenerCliente(id);
    if (cliente != null) {
      _funcionarios = List.from(cliente.funcionarios);
      notifyListeners();
    }
    return cliente;
  }

  // CRUD Clientes
  Future<bool> crearCliente(ClienteModel cliente) async {
    final success = await ClientesApiService.crearCliente(cliente);
    if (success) {
      await cargarClientes();
    }
    return success;
  }

  Future<bool> actualizarCliente(ClienteModel cliente) async {
    final success = await ClientesApiService.actualizarCliente(cliente);
    if (success) {
      await cargarClientes();
    }
    return success;
  }

  Future<bool> eliminarCliente(int id) async {
    final success = await ClientesApiService.eliminarCliente(id);
    if (success) {
      await cargarClientes();
    }
    return success;
  }

  // Gestión de Funcionarios
  Future<void> cargarFuncionarios(int clienteId) async {
    _loadingFuncionarios = true;
    notifyListeners();
    try {
      _funcionarios = await ServiciosApiService.listarFuncionarios(
        clienteId: clienteId,
      );
    } catch (e) {
      if (kDebugMode) print('Error cargando funcionarios: $e');
      _funcionarios = [];
    } finally {
      _loadingFuncionarios = false;
      notifyListeners();
    }
  }

  Future<bool> crearFuncionario({
    required String nombre,
    String? cargo,
    String? empresa,
    String? telefono,
    String? correo,
    int? clienteId,
  }) async {
    final res = await ServiciosApiService.crearFuncionario(
      nombre: nombre,
      cargo: cargo,
      empresa: empresa,
      telefono: telefono,
      correo: correo,
      clienteId: clienteId,
    );
    if (res.isSuccess && clienteId != null) {
      await cargarFuncionarios(clienteId);
    }
    return res.isSuccess;
  }

  Future<bool> actualizarFuncionario({
    required int funcionarioId,
    required String nombre,
    String? cargo,
    String? empresa,
    String? telefono,
    String? correo,
    int? clienteId,
  }) async {
    final res = await ServiciosApiService.actualizarFuncionario(
      funcionarioId: funcionarioId,
      nombre: nombre,
      cargo: cargo,
      empresa: empresa,
      telefono: telefono,
      correo: correo,
      clienteId: clienteId,
    );
    if (res.isSuccess && clienteId != null) {
      await cargarFuncionarios(clienteId);
    }
    return res.isSuccess;
  }

  Future<bool> eliminarFuncionario(int id, {int? clienteId}) async {
    final res = await ServiciosApiService.eliminarFuncionario(id);
    if (res.isSuccess && clienteId != null) {
      await cargarFuncionarios(clienteId);
    }
    return res.isSuccess;
  }

  // Agregar ciudad on the fly
  Future<CiudadModel?> crearCiudad(CiudadModel ciudad) async {
    final nueva = await CiudadesApiService.crearCiudad(ciudad);
    if (nueva != null) {
      _ciudades.add(nueva);
      // Reordenar
      _ciudades.sort((a, b) => (a.nombre ?? '').compareTo(b.nombre ?? ''));
      notifyListeners();
    }
    return nueva;
  }
}
