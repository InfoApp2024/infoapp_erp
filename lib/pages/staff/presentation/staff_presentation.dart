// =====================================================
// PRESENTATION LAYER - Controller + State Management
// VERSIÓN REAL - CON SERVICIOS DE BASE DE DATOS ACTIVADOS
// PARTE 1 DE 3: STATE CLASSES Y CONTROLLER BÁSICO
// =====================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../domain/staff_domain.dart';
import '../models/staff_model.dart';
import '../services/staff_services.dart';

// ✅ STATE CLASSES CORREGIDAS - SIN TIPOS NULLABLE PROBLEMÁTICOS
class StaffState {
  final List<Staff> staffList;
  final List<Department> departments;
  final List<Position> positions;
  final List<Map<String, dynamic>>
  specialties; // ✅ Nueva lista de especialidades
  final bool isLoading;
  final String? error;
  final Staff? selectedStaff;
  final String searchText;
  final bool activeFilter;
  final String? selectedDepartmentId;
  final bool isCreating;
  final bool isUpdating;
  final bool isDeleting;
  // ✅ CAMBIO CRÍTICO: includeInactive ahora es bool NO NULLABLE
  final bool includeInactive;

  StaffState({
    this.staffList = const [],
    this.departments = const [],
    this.positions = const [],
    this.specialties = const [], // ✅ Inicialización
    this.isLoading = false,
    this.error,
    this.selectedStaff,
    this.searchText = '',
    this.activeFilter = true,
    this.selectedDepartmentId,
    this.isCreating = false,
    this.isUpdating = false,
    this.isDeleting = false,
    // ✅ VALOR POR DEFECTO SEGURO
    this.includeInactive = false,
  });

  StaffState copyWith({
    List<Staff>? staffList,
    List<Department>? departments,
    List<Position>? positions,
    List<Map<String, dynamic>>? specialties, // ✅ Parámetro opcional
    bool? isLoading,
    String? error,
    Staff? selectedStaff,
    String? searchText,
    bool? activeFilter,
    String? selectedDepartmentId,
    bool? isCreating,
    bool? isUpdating,
    bool? isDeleting,
    bool clearError = false,
    bool clearSelectedStaff = false,
    bool clearSelectedDepartmentId = false,
    // ✅ CORREGIDO: includeInactive como bool, no nullable
    bool? includeInactive,
  }) {
    return StaffState(
      staffList: staffList ?? this.staffList,
      departments: departments ?? this.departments,
      positions: positions ?? this.positions,
      specialties: specialties ?? this.specialties, // ✅ Asignación
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedStaff:
          clearSelectedStaff ? null : (selectedStaff ?? this.selectedStaff),
      searchText: searchText ?? this.searchText,
      activeFilter: activeFilter ?? this.activeFilter,
      selectedDepartmentId:
          clearSelectedDepartmentId
              ? null
              : (selectedDepartmentId ?? this.selectedDepartmentId),
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      isDeleting: isDeleting ?? this.isDeleting,
      // ✅ ASIGNACIÓN SEGURA
      includeInactive: includeInactive ?? this.includeInactive,
    );
  }

  // ✅ GETTER FILTEREDSTAFF CORREGIDO COMPLETAMENTE
  List<Staff> get filteredStaff {
    var filtered = staffList.toList();

    // Filter by search text
    if (searchText.isNotEmpty) {
      filtered =
          filtered
              .where(
                (staff) =>
                    staff.firstName.toLowerCase().contains(
                      searchText.toLowerCase(),
                    ) ||
                    staff.lastName.toLowerCase().contains(
                      searchText.toLowerCase(),
                    ) ||
                    staff.email.toLowerCase().contains(
                      searchText.toLowerCase(),
                    ) ||
                    staff.staffCode.toLowerCase().contains(
                      searchText.toLowerCase(),
                    ),
              )
              .toList();
    }

    // ✅ FILTRO POR ESTADO COMPLETAMENTE CORREGIDO - CON PROTECCIÓN ADICIONAL
    // Usar comparación explícita para evitar problemas de inicialización
    if (includeInactive == true) {
      // Mostrar todos (activos e inactivos) - no filtrar
      // No aplicar ningún filtro de estado
    } else if (activeFilter == true) {
      // Mostrar solo activos
      filtered = filtered.where((staff) => staff.isActive).toList();
    } else {
      // Mostrar solo inactivos
      filtered = filtered.where((staff) => !staff.isActive).toList();
    }

    // Filter by department
    if (selectedDepartmentId != null && selectedDepartmentId!.isNotEmpty) {
      filtered =
          filtered
              .where((staff) => staff.departmentId == selectedDepartmentId)
              .toList();
    }

    return filtered;
  }

  bool get hasData => staffList.isNotEmpty;
  bool get hasError => error != null;
  bool get isProcessing => isLoading || isCreating || isUpdating || isDeleting;
}

// ✅ CONTROLLER PARTE 1 - INICIALIZACIÓN Y GETTERS SEGUROS
class StaffController extends GetxController {
  // Reactive State
  final Rx<StaffState> _state = StaffState().obs;
  StaffState get state => _state.value;

  // Getters for easy access - ✅ TODOS SEGUROS
  List<Staff> get staffList => state.staffList;
  List<Staff> get filteredStaff => state.filteredStaff;
  List<Department> get departments => state.departments;
  List<Position> get positions => state.positions;
  List<Map<String, dynamic>> get specialties => state.specialties; // ✅ Getter
  bool get isLoading => state.isLoading;
  String? get error => state.error;
  Staff? get selectedStaff => state.selectedStaff;

  // ✅ VARIABLE DE REFERENCIA PARA EDICIÓN
  Staff? editingStaff;

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
  }

  // ✅ INITIAL DATA LOADING - VERSIÓN REAL ACTIVADA CON MANEJO DE ERRORES MEJORADO
  Future<void> loadInitialData() async {
    //     print('🚀 Iniciando carga REAL de datos...');
    _updateState(isLoading: true, clearError: true);

    try {
      // ✅ 1. CARGAR EMPLEADOS DESDE LA BASE DE DATOS (REAL)
      //       print('📡 Cargando empleados desde DB...');

      final staffResponse = await StaffApiService.getStaffList();

      if (staffResponse.success && staffResponse.data != null) {
        //         print('✅ ${staffResponse.data!.length} empleados cargados desde DB');
        _updateState(
          staffList: staffResponse.data!,
          isLoading: false,
          clearError: true,
        );
      } else {
        throw Exception(staffResponse.message ?? 'Error cargando empleados');
      }

      // ✅ 2. CARGAR DEPARTAMENTOS Y POSICIONES (REAL)
      await _loadDepartmentsAndPositions();

      //       print('✅ Todos los datos iniciales cargados correctamente');
      _showInfoSnackbar('Datos cargados desde la base de datos');
    } catch (e) {
      //       print('❌ Error cargando datos iniciales: $e');
      _updateState(isLoading: false, error: e.toString());

      // Mensaje específico según el tipo de error
      String errorMessage = e.toString();
      if (errorMessage.contains('Connection') ||
          errorMessage.contains('Network')) {
        errorMessage =
            'Error de conexión. Verifique su internet y el servidor.';
      } else if (errorMessage.contains('timeout')) {
        errorMessage = 'Tiempo de espera agotado. Intente nuevamente.';
      }

      _showErrorSnackbar('Error cargando datos iniciales', errorMessage);
    }
  }

  // ✅ LOAD DEPARTMENTS, POSITIONS AND SPECIALTIES - VERSIÓN REAL CORREGIDA CON TIPOS
  Future<void> _loadDepartmentsAndPositions() async {
    try {
      //       print('📡 Cargando departamentos y posiciones...');

      // ✅ CARGAR SECUENCIALMENTE PARA EVITAR PROBLEMAS DE TIPOS
      //       print('📡 Cargando departamentos...');
      final deptResponse = await StaffApiService.getDepartmentsList();

      //       print('📡 Cargando posiciones...');
      final posResponse = await StaffApiService.getPositionsList();

      //       print('📡 Cargando especialidades...');
      final specResponse = await StaffApiService.getSpecialties();

      List<Department> departments = [];
      List<Position> positions = [];
      List<Map<String, dynamic>> specialties = [];

      // ✅ PROCESAR DEPARTAMENTOS CON VALIDACIÓN
      if (deptResponse.success && deptResponse.data != null) {
        departments = deptResponse.data!;
        //         print('✅ ${departments.length} departamentos cargados');
      } else {
        //         print('⚠️ Error cargando departamentos: ${deptResponse.message}');
      }

      // ✅ PROCESAR POSICIONES CON VALIDACIÓN
      if (posResponse.success && posResponse.data != null) {
        positions = posResponse.data!;
        //         print('✅ ${positions.length} posiciones cargadas');
      } else {
        //         print('⚠️ Error cargando posiciones: ${posResponse.message}');
      }

      // ✅ PROCESAR ESPECIALIDADES CON VALIDACIÓN
      if (specResponse.success && specResponse.data != null) {
        specialties = specResponse.data!;
        //         print('✅ ${specialties.length} especialidades cargadas');
      } else {
        //         print('⚠️ Error cargando especialidades: ${specResponse.message}');
      }

      _updateState(
        departments: departments,
        positions: positions,
        specialties: specialties,
      );
    } catch (e) {
      //       print('⚠️ Error loading departments/positions/specialties: $e');
      // No lanzar excepción, solo log
    }
  }

  // ✅ SEARCH STAFF - VERSIÓN REAL CON MANEJO DE ERRORES MEJORADO
  Future<void> searchStaff(String searchText) async {
    _updateState(searchText: searchText, clearError: true);

    // Si la búsqueda está vacía, recargar datos completos
    if (searchText.trim().isEmpty) {
      //       print('🔍 Búsqueda vacía, recargando todos los datos...');
      await loadInitialData();
      return;
    }

    _updateState(isLoading: true, clearError: true);

    try {
      // ✅ BÚSQUEDA REAL EN LA BASE DE DATOS
      //       print('🔍 Búsqueda real en DB: "$searchText"');

      final response = await StaffApiService.searchStaffList(
        search: searchText,
        limit: 50,
      );

      if (response.success && response.data != null) {
        //         print('✅ ${response.data!.length} resultados encontrados');
        _updateState(staffList: response.data!, isLoading: false);
        _showInfoSnackbar(
          'Búsqueda completada: ${response.data!.length} resultados',
        );
      } else {
        throw Exception(response.message ?? 'Error en búsqueda');
      }
    } catch (e) {
      //       print('❌ Error en búsqueda: $e');
      _updateState(isLoading: false, error: e.toString());
      _showErrorSnackbar('Error en búsqueda', e.toString());
    }
  }

  // ✅ TOGGLE ACTIVE FILTER CORREGIDO
  void toggleActiveFilter() {
    _updateState(activeFilter: !state.activeFilter);
    _refreshStaffList();
  }

  // ✅ UPDATE DEPARTMENT FILTER CON VALIDACIÓN
  void updateDepartmentFilter(String? departmentId) {
    //     print('🏢 Actualizando filtro de departamento: $departmentId');
    if (departmentId == null || departmentId.isEmpty) {
      _updateState(clearSelectedDepartmentId: true);
    } else {
      _updateState(selectedDepartmentId: departmentId);
    }
    _refreshStaffList();
  }

  // ✅ REFRESH STAFF LIST - VERSIÓN REAL CON PARÁMETROS CORREGIDOS
  Future<void> _refreshStaffList() async {
    _updateState(isLoading: true, clearError: true);

    try {
      // ✅ RECARGAR DATOS REALES APLICANDO FILTROS
      //       print('🔄 Recargando lista con filtros...');
      //       print('  - activeFilter: ${state.activeFilter}');
      //       print('  - includeInactive: ${state.includeInactive}');
      //       print('  - selectedDepartmentId: ${state.selectedDepartmentId}');

      final response = await StaffApiService.getStaffList(
        departmentId:
            state.selectedDepartmentId != null
                ? int.tryParse(state.selectedDepartmentId!)
                : null,
        // ✅ LÓGICA DE FILTRO CORREGIDA
        isActive:
            state.includeInactive
                ? null // Mostrar todos si includeInactive es true
                : state
                    .activeFilter, // Usar activeFilter si includeInactive es false
        includeInactive: state.includeInactive,
        search: state.searchText.isNotEmpty ? state.searchText : null,
        limit: 100,
      );

      if (response.success && response.data != null) {
        _updateState(staffList: response.data!, isLoading: false);
        _showInfoSnackbar(
          'Lista actualizada: ${response.data!.length} empleados',
        );
      } else {
        throw Exception(response.message ?? 'Error actualizando lista');
      }
    } catch (e) {
      //       print('❌ Error actualizando lista: $e');
      _updateState(isLoading: false, error: e.toString());
      _showErrorSnackbar('Error actualizando lista', e.toString());
    }
  }

  // ✅ CREATE STAFF - VERSIÓN REAL CON VALIDACIONES MEJORADAS
  Future<void> createStaff(Staff staff) async {
    //     print('💾 Iniciando creación REAL de empleado: ${staff.fullName}');
    _updateState(isCreating: true, clearError: true);

    try {
      // ✅ 1. VALIDACIONES PREVIAS DE UNICIDAD
      //       print('🔍 Validando unicidad de datos...');

      // Validar email único
      //       print('📧 Verificando email: ${staff.email}');
      final emailResponse = await StaffApiService.isEmailAvailable(staff.email);
      if (!emailResponse.success || !(emailResponse.data ?? false)) {
        throw Exception('El email ${staff.email} ya está registrado');
      }

      // Validar identificación única
      //       print('🆔 Verificando identificación: ${staff.identificationNumber}');
      final idResponse = await StaffApiService.isIdentificationAvailable(
        staff.identificationNumber,
      );
      if (!idResponse.success || !(idResponse.data ?? false)) {
        throw Exception(
          'El número de identificación ${staff.identificationNumber} ya está registrado',
        );
      }

      // ✅ 2. CREAR EN LA BASE DE DATOS
      //       print('📡 Enviando datos al servidor...');

      final response = await StaffApiService.createStaff(staff as StaffModel);

      if (response.success && response.data != null) {
        //         print('✅ Empleado creado en DB: ID ${response.data!.id}');

        // ✅ 3. ACTUALIZAR LISTA LOCAL con datos del servidor
        final updatedList = [...state.staffList, response.data!];

        _updateState(
          staffList: updatedList,
          isCreating: false,
          clearError: true,
        );

        // ✅ 4. RECARGAR LISTAS RELACIONADAS (por si se crearon departamentos/posiciones)
        await _loadDepartmentsAndPositions();

        _showSuccessSnackbar(
          'Empleado creado exitosamente en la base de datos',
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (Get.currentRoute.contains('/staff/form') ||
            Get.currentRoute.contains('form')) {
          Get.back(result: response.data!);
        }
      } else {
        throw Exception(response.message ?? 'Error desconocido del servidor');
      }
    } catch (e) {
      //       print('❌ Error creando empleado en DB: $e');
      _updateState(isCreating: false, error: e.toString());

      // Mensaje de error específico
      String errorMessage = e.toString();
      if (errorMessage.contains('email')) {
        errorMessage = 'Email ya registrado. Use otro email.';
      } else if (errorMessage.contains('identificación') ||
          errorMessage.contains('identification')) {
        errorMessage = 'Número de identificación ya registrado.';
      } else if (errorMessage.contains('Connection')) {
        errorMessage = 'Error de conexión. Verifique su internet.';
      }

      _showErrorSnackbar('Error creando empleado', errorMessage);

      // ✅ ASEGURAR QUE LA EXCEPCIÓN SE PROPAGUE CORRECTAMENTE
      //       print('❌ Lanzando excepción desde createStaff hacia saveStaff');
      rethrow; // ✅ USAR rethrow EN LUGAR DE throw e
    }
  }

  // ✅ UPDATE STAFF - VERSIÓN REAL CON VALIDACIONES MEJORADAS
  Future<void> updateStaff(Staff staff) async {
    //     print('💾 Iniciando actualización REAL de empleado: ${staff.fullName}');
    _updateState(isUpdating: true, clearError: true);

    try {
      // ✅ 1. VALIDACIONES PREVIAS DE UNICIDAD (excluyendo el empleado actual)
      //       print('🔍 Validando cambios de datos...');

      if (editingStaff?.email != staff.email) {
        //         print('📧 Verificando nuevo email: ${staff.email}');
        final emailResponse = await StaffApiService.isEmailAvailable(
          staff.email,
          excludeStaffId: staff.id,
        );
        if (!emailResponse.success || !(emailResponse.data ?? false)) {
          throw Exception(
            'El email ${staff.email} ya está registrado por otro empleado',
          );
        }
      }

      if (editingStaff?.identificationNumber != staff.identificationNumber) {
        //         print('🆔 Verificando nueva identificación: ${staff.identificationNumber}');
        final idResponse = await StaffApiService.isIdentificationAvailable(
          staff.identificationNumber,
          excludeStaffId: staff.id,
        );
        if (!idResponse.success || !(idResponse.data ?? false)) {
          throw Exception(
            'El número de identificación ${staff.identificationNumber} ya está registrado por otro empleado',
          );
        }
      }

      // ✅ 2. ACTUALIZAR EN LA BASE DE DATOS
      //       print('📡 Enviando actualización al servidor...');

      final response = await StaffApiService.updateStaff(staff as StaffModel);

      if (response.success && response.data != null) {
        //         print('✅ Empleado actualizado en DB: ID ${response.data!.id}');

        // ✅ 3. ACTUALIZAR LISTA LOCAL
        final updatedList =
            state.staffList.map((s) {
              return s.id == staff.id ? response.data! : s;
            }).toList();

        _updateState(
          staffList: updatedList,
          selectedStaff: response.data,
          isUpdating: false,
          clearError: true,
        );

        _showSuccessSnackbar(
          'Empleado actualizado exitosamente en la base de datos',
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (Get.currentRoute.contains('/staff/form')) {
          Get.back(result: response.data!);
        }
      } else {
        throw Exception(response.message ?? 'Error actualizando empleado');
      }
    } catch (e) {
      //       print('❌ Error actualizando empleado: $e');
      _updateState(isUpdating: false, error: e.toString());

      String errorMessage = e.toString();
      if (errorMessage.contains('email')) {
        errorMessage = 'Email ya registrado por otro empleado.';
      } else if (errorMessage.contains('identificación') ||
          errorMessage.contains('identification')) {
        errorMessage =
            'Número de identificación ya registrado por otro empleado.';
      } else if (errorMessage.contains('Connection')) {
        errorMessage = 'Error de conexión. Verifique su internet.';
      }

      _showErrorSnackbar('Error actualizando empleado', errorMessage);

      // ✅ ASEGURAR QUE LA EXCEPCIÓN SE PROPAGUE CORRECTAMENTE
      //       print('❌ Lanzando excepción desde updateStaff hacia saveStaff');
      rethrow; // ✅ USAR rethrow EN LUGAR DE throw e
    }
  }

  // ✅ TOGGLE STAFF STATUS - VERSIÓN REAL CON VALIDACIÓN MEJORADA
  Future<void> toggleStaffStatus(String staffId) async {
    //     print('🔄 Cambiando estado REAL del empleado: $staffId');

    // ✅ VALIDAR QUE EL ID NO ESTÉ VACÍO
    if (staffId.trim().isEmpty) {
      _showErrorSnackbar('Error', 'ID de empleado inválido');
      return;
    }

    // ✅ USAR isUpdating EN LUGAR DE isDeleting PARA MEJOR UX
    _updateState(isUpdating: true, clearError: true);

    try {
      // ✅ USAR SERVICIO SIMPLIFICADO DE TOGGLE STATUS
      //       print('📡 Enviando cambio de estado al servidor...');

      final response = await StaffApiService.toggleStaffStatus(
        staffId: staffId,
      );

      if (response.success && response.data != null) {
        //         print('✅ Estado cambiado exitosamente en DB');

        // ✅ ACTUALIZAR LISTA LOCAL con respuesta del servidor
        final updatedList =
            state.staffList.map((s) {
              return s.id == staffId ? response.data! : s;
            }).toList();

        _updateState(
          staffList: updatedList,
          isUpdating: false,
          clearError: true,
        );

        final status = response.data!.isActive ? 'activado' : 'desactivado';
        _showSuccessSnackbar('Empleado $status exitosamente');

        //         print('✅ Estado cambiado localmente, no es necesario refrescar');
      } else {
        throw Exception(response.message ?? 'Error cambiando estado');
      }
    } catch (e) {
      //       print('❌ Error cambiando estado: $e');
      _updateState(isUpdating: false, error: e.toString());

      // ✅ MENSAJE DE ERROR MÁS CLARO
      String errorMessage = e.toString();
      if (errorMessage.contains('get_staff_detail')) {
        errorMessage = 'Error temporal del servidor. Intente nuevamente.';
      } else if (errorMessage.contains('HTTP 500')) {
        errorMessage = 'Error interno del servidor. Intente más tarde.';
      }

      _showErrorSnackbar('Error cambiando estado', errorMessage);
    }
  }

  // ✅ STAFF SELECTION METHODS
  void selectStaff(Staff staff) {
    _updateState(selectedStaff: staff);
  }

  void clearSelectedStaff() {
    _updateState(clearSelectedStaff: true);
  }

  // ✅ IMPORT/EXPORT OPERATIONS - VERSIÓN REAL CON MANEJO DE ERRORES
  Future<void> importStaff() async {
    _updateState(isLoading: true, clearError: true);

    try {
      // TODO: Implementar file picker real y llamada al servicio
      _showInfoSnackbar('Seleccione archivo para importar...');

      // Para el futuro:
      // final result = await StaffApiService.importStaffFromFile(...);
      // if (result.success) {
      //   await loadInitialData(); // Recargar datos
      //   _showSuccessSnackbar('${result.data?.insertados ?? 0} empleados importados');
      // }

      _updateState(isLoading: false);
      _showInfoSnackbar('Importación próximamente disponible');
    } catch (e) {
      _updateState(isLoading: false, error: e.toString());
      _showErrorSnackbar('Error importando datos', e.toString());
    }
  }

  Future<void> exportToExcel() async {
    try {
      _showInfoSnackbar('Exportando a Excel...');

      // ✅ VALIDAR QUE HAY DATOS PARA EXPORTAR
      if (state.staffList.isEmpty) {
        _showInfoSnackbar('No hay empleados para exportar');
        return;
      }

      // ✅ USAR SERVICIO REAL DE EXPORTACIÓN
      final response = await StaffApiService.exportStaffToExcel(
        staff: state.staffList.cast<StaffModel>(),
      );

      if (response.success && response.data != null) {
        _showSuccessSnackbar('Datos exportados a Excel correctamente');
        //         print('✅ Staff exported to Excel: ${response.data!.length} bytes');

        // TODO: Aquí se podría guardar o compartir el archivo
        // final bytes = response.data!;
        // await SaveFile.saveBytes(bytes, 'empleados.xlsx');
      } else {
        throw Exception(response.message ?? 'Error exportando Excel');
      }
    } catch (e) {
      //       print('❌ Error exportando Excel: $e');
      _showErrorSnackbar('Error exportando Excel', e.toString());
    }
  }

  Future<void> exportToCSV() async {
    try {
      _showInfoSnackbar('Exportando a CSV...');

      // ✅ VALIDAR QUE HAY DATOS PARA EXPORTAR
      if (state.staffList.isEmpty) {
        _showInfoSnackbar('No hay empleados para exportar');
        return;
      }

      // TODO: Implementar método CSV en el servicio
      // Por ahora usar Excel y convertir
      _showSuccessSnackbar('Exportación CSV próximamente disponible');
    } catch (e) {
      //       print('❌ Error exportando CSV: $e');
      _showErrorSnackbar('Error exportando CSV', e.toString());
    }
  }

  // ✅ UTILITY METHODS MEJORADOS
  Future<void> refreshData() async {
    //     print('🔄 Refrescando datos...');
    await loadInitialData();
  }

  void clearError() {
    _updateState(clearError: true);
  }

  // ✅ MÉTODOS PARA GESTIONAR FILTROS DE ESTADO - COMPLETAMENTE CORREGIDOS
  void setStatusFilter({
    bool activeOnly = false,
    bool inactiveOnly = false,
    bool showAll = false,
  }) {
    //     print('🔄 Estableciendo filtro de estado - Active: $activeOnly, Inactive: $inactiveOnly, ShowAll: $showAll');

    // ✅ ACTUALIZAR ESTADO INMEDIATAMENTE
    if (showAll) {
      _updateState(activeFilter: true, includeInactive: true, clearError: true);
    } else if (inactiveOnly) {
      _updateState(
        activeFilter: false,
        includeInactive: false,
        clearError: true,
      );
    } else {
      // activeOnly por defecto
      _updateState(
        activeFilter: true,
        includeInactive: false,
        clearError: true,
      );
    }

    // ✅ APLICAR FILTRO INMEDIATAMENTE SIN DELAY
    _refreshStaffList();
  }

  void clearAllFilters() {
    //     print('🧹 Limpiando todos los filtros');

    // ✅ ACTUALIZAR ESTADO INMEDIATAMENTE
    _updateState(
      searchText: '',
      activeFilter: true,
      includeInactive: false,
      clearSelectedDepartmentId: true,
      clearError: true,
    );

    // ✅ RECARGAR SOLO UNA VEZ CON ESTADO LIMPIO
    _refreshStaffListWithCleanState();
  }

  // ✅ MÉTODO AUXILIAR PARA RECARGAR CON ESTADO LIMPIO
  Future<void> _refreshStaffListWithCleanState() async {
    _updateState(isLoading: true, clearError: true);

    try {
      //       print('🔄 Recargando lista con estado limpio...');

      final response = await StaffApiService.getStaffList(
        isActive: true, // ✅ SOLO ACTIVOS POR DEFECTO
        includeInactive: false,
        limit: 100,
      );

      if (response.success && response.data != null) {
        _updateState(
          staffList: response.data!,
          isLoading: false,
          clearError: true,
        );
        //         print('✅ Lista recargada con filtros limpios: ${response.data!.length} empleados');
      } else {
        throw Exception(response.message ?? 'Error recargando lista');
      }
    } catch (e) {
      //       print('❌ Error recargando con estado limpio: $e');
      _updateState(isLoading: false, error: e.toString());
    }
  }

  // ✅ UTILITY METHODS PARA TRABAJAR CON DEPARTMENTS Y POSITIONS
  List<Position> getPositionsForDepartment(String departmentId) {
    if (departmentId.trim().isEmpty) return [];
    return positions.where((pos) => pos.departmentId == departmentId).toList();
  }

  String getDepartmentName(String departmentId) {
    if (departmentId.trim().isEmpty) return 'Sin departamento';

    try {
      final dept = departments.firstWhere((dept) => dept.id == departmentId);
      return dept.name;
    } catch (e) {
      //       print('⚠️ Departamento no encontrado: $departmentId');
      return 'Departamento no encontrado';
    }
  }

  String getPositionTitle(String positionId) {
    if (positionId.trim().isEmpty) return 'Sin posición';

    try {
      final position = positions.firstWhere((pos) => pos.id == positionId);
      return position.title;
    } catch (e) {
      //       print('⚠️ Posición no encontrada: $positionId');
      return 'Cargo no encontrado';
    }
  }

  // ✅ VALIDATION HELPERS MEJORADOS
  bool validateStaffData(Staff staff) {
    // Validación básica local
    if (staff.firstName.trim().isEmpty ||
        staff.lastName.trim().isEmpty ||
        staff.email.trim().isEmpty ||
        staff.identificationNumber.trim().isEmpty) {
      _showErrorSnackbar(
        'Errores de validación',
        'Campos obligatorios faltantes',
      );
      return false;
    }

    // Validar formato de email
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(staff.email)) {
      _showErrorSnackbar('Error de validación', 'Formato de email inválido');
      return false;
    }

    // ✅ VALIDAR DEPARTAMENTO Y POSICIÓN
    if (staff.departmentId.trim().isEmpty) {
      _showErrorSnackbar('Error de validación', 'Departamento es obligatorio');
      return false;
    }

    if (staff.positionId.trim().isEmpty) {
      _showErrorSnackbar('Error de validación', 'Posición es obligatoria');
      return false;
    }

    return true;
  }

  // ✅ PRIVATE METHODS - _updateState CORREGIDO
  void _updateState({
    List<Staff>? staffList,
    List<Department>? departments,
    List<Position>? positions,
    List<Map<String, dynamic>>? specialties,
    bool? isLoading,
    String? error,
    Staff? selectedStaff,
    String? searchText,
    bool? activeFilter,
    String? selectedDepartmentId,
    bool? isCreating,
    bool? isUpdating,
    bool? isDeleting,
    bool clearError = false,
    bool clearSelectedStaff = false,
    bool clearSelectedDepartmentId = false,
    bool? includeInactive, // ✅ AHORA ES bool?, PERO SE MANEJA CORRECTAMENTE
  }) {
    _state.value = state.copyWith(
      staffList: staffList,
      departments: departments,
      positions: positions,
      specialties: specialties,
      isLoading: isLoading,
      error: error,
      selectedStaff: selectedStaff,
      searchText: searchText,
      activeFilter: activeFilter,
      selectedDepartmentId: selectedDepartmentId,
      isCreating: isCreating,
      isUpdating: isUpdating,
      isDeleting: isDeleting,
      clearError: clearError,
      clearSelectedStaff: clearSelectedStaff,
      clearSelectedDepartmentId: clearSelectedDepartmentId,
      includeInactive: includeInactive, // ✅ SE MANEJA EN copyWith CORRECTAMENTE
    );
  }

  // ✅ MÉTODOS DE FEEDBACK MEJORADOS
  void _showSuccessSnackbar(String message) {
    Get.snackbar(
      'Éxito',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.primaryColor,
      colorText: Get.theme.colorScheme.onPrimary,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
    );
  }

  void _showErrorSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
      duration: const Duration(seconds: 5),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
    );
  }

  void _showInfoSnackbar(String message) {
    Get.snackbar(
      'Información',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.surface,
      colorText: Get.theme.colorScheme.onSurface,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
    );
  }
}

// ✅ DEPENDENCY INJECTION - MEJORADO CON MANEJO DE ERRORES
class StaffBinding extends Bindings {
  @override
  void dependencies() {
    //     print('🔧 StaffBinding - Registrando dependencias...');

    try {
      if (!Get.isRegistered<StaffController>()) {
        Get.lazyPut<StaffController>(() => StaffController(), fenix: true);
        //         print('✅ StaffController registrado');
      }

      if (!Get.isRegistered<StaffFormController>()) {
        Get.lazyPut<StaffFormController>(
          () => StaffFormController(),
          fenix: true,
        );
        //         print('✅ StaffFormController registrado');
      }

      //       print('✅ StaffBinding - Dependencias registradas correctamente');
    } catch (e) {
      //       print('❌ Error registrando dependencias: $e');
    }
  }
}

// ✅ FORM CONTROLLER - COMPLETAMENTE CORREGIDO PARA EVITAR ERRORES GETX
class StaffFormController extends GetxController {
  // ✅ CONTROLLERS DE TEXTO
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final identificationController = TextEditingController();
  final addressController = TextEditingController();
  final salaryController = TextEditingController();
  final emergencyNameController = TextEditingController();
  final emergencyPhoneController = TextEditingController();

  // ✅ DROPDOWNS y SELECCIONES - INICIALIZADOS CORRECTAMENTE
  final departmentId = RxnString();
  final positionId = RxnString();
  final especialidadId = RxnString(); // ✅ Nueva especialidad
  final identificationType = IdentificationType.dni.obs;

  // ✅ FECHAS CON VALORES SEGUROS
  final hireDate = Rx<DateTime>(DateTime.now());
  final birthDate = Rxn<DateTime>();

  // ✅ OTROS CAMPOS
  final photoUrl = RxnString();
  final isActive = true.obs;

  // ✅ ESTADO DEL FORMULARIO
  final isFormValid = false.obs;
  final formErrors = <String, String>{}.obs;

  // ✅ FLAG DE ÉXITO PARA CONTROLAR CIERRE DEL FORMULARIO
  final formSuccessful = false.obs;

  // ✅ EMPLEADO EN EDICIÓN
  Staff? editingStaff;

  @override
  void onInit() {
    super.onInit();
    _setupValidation();
  }

  // ✅ VALIDACIÓN COMPLETAMENTE CORREGIDA PARA EVITAR ERRORES GetX
  void _setupValidation() {
    //     print('🔧 Configurando validación del formulario...');

    // ✅ LISTENERS CON DEBOUNCE PARA EVITAR EXCESO DE VALIDACIONES
    Timer? validationTimer;

    void scheduleValidation() {
      validationTimer?.cancel();
      validationTimer = Timer(const Duration(milliseconds: 300), () {
        if (isClosed) return; // ✅ VERIFICAR SI EL CONTROLLER ESTÁ CERRADO
        _validateForm();
      });
    }

    // ✅ LISTENERS SEGUROS PARA TEXT CONTROLLERS
    firstNameController.addListener(scheduleValidation);
    lastNameController.addListener(scheduleValidation);
    emailController.addListener(scheduleValidation);
    identificationController.addListener(scheduleValidation);
    phoneController.addListener(scheduleValidation);

    // ✅ LISTENERS PARA OBSERVABLES (SEGUROS)
    ever(departmentId, (_) => scheduleValidation());
    ever(positionId, (_) => scheduleValidation());
    ever(
      especialidadId,
      (_) => scheduleValidation(),
    ); // ✅ Listener para especialidad
    ever(identificationType, (_) => scheduleValidation());

    // ✅ VALIDACIÓN INICIAL DESPUÉS DE UN DELAY
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!isClosed) _validateForm();
    });
  }

  void _validateForm() {
    if (isClosed) return; // ✅ SEGURIDAD ADICIONAL

    try {
      // ✅ LIMPIAR ERRORES PREVIOS
      formErrors.clear();

      // ✅ VALIDAR CAMPOS OBLIGATORIOS
      if (firstNameController.text.trim().isEmpty) {
        formErrors['firstName'] = 'Nombre requerido';
      }

      if (lastNameController.text.trim().isEmpty) {
        formErrors['lastName'] = 'Apellido requerido';
      }

      final email = emailController.text.trim();
      if (email.isEmpty) {
        formErrors['email'] = 'Email requerido';
      } else if (!_isValidEmail(email)) {
        formErrors['email'] = 'Email inválido';
      }

      // ✅ VALIDAR DEPARTAMENTO CON VERIFICACIÓN SEGURA
      final deptId = departmentId.value;
      if (deptId == null || deptId.trim().isEmpty) {
        formErrors['departmentId'] = 'Departamento requerido';
      }

      // ✅ VALIDAR POSICIÓN CON VERIFICACIÓN SEGURA
      final posId = positionId.value;
      if (posId == null || posId.trim().isEmpty) {
        formErrors['positionId'] = 'Posición requerida';
      }

      // ✅ VALIDAR IDENTIFICACIÓN
      final identification = identificationController.text.trim();
      if (identification.isEmpty) {
        formErrors['identificationNumber'] =
            'Número de identificación requerido';
      }

      // ✅ ESTABLECER VALIDEZ DEL FORMULARIO DE FORMA SEGURA
      final isValid = formErrors.isEmpty;

      // ✅ ACTUALIZACIÓN SEGURA DEL ESTADO
      if (!isClosed) {
        isFormValid.value = isValid;

        // ✅ DEBUG OPCIONAL (solo si está habilitado)
        if (false) {
          // Cambiar a true para debug
          //           print('🔍 Formulario validado - Válido: $isValid, Errores: ${formErrors.length}');
        }
      }
    } catch (e) {
      //       print('❌ Error en validación del formulario: $e');
      // En caso de error, marcar como inválido por seguridad
      if (!isClosed) {
        isFormValid.value = false;
      }
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // ✅ CONVERSIÓN A STAFF MEJORADA CON VALIDACIONES
  Staff toStaff() {
    return StaffModel(
      id: editingStaff?.id ?? '',
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      email: emailController.text.trim(),
      departmentId: departmentId.value?.trim() ?? '1', // ✅ VALOR SEGURO
      positionId: positionId.value?.trim() ?? '1', // ✅ VALOR SEGURO
      especialidadId: especialidadId.value?.trim(), // ✅ Campo opcional
      identificationNumber: identificationController.text.trim(),
      identificationType: identificationType.value,
      staffCode: editingStaff?.staffCode ?? _generateStaffCode(),
      hireDate: hireDate.value,
      phone:
          phoneController.text.trim().isNotEmpty
              ? phoneController.text.trim()
              : null,
      birthDate: birthDate.value,
      photoUrl: photoUrl.value,
      salary:
          salaryController.text.trim().isNotEmpty
              ? double.tryParse(salaryController.text.trim())
              : null,
      address:
          addressController.text.trim().isNotEmpty
              ? addressController.text.trim()
              : null,
      emergencyContactName:
          emergencyNameController.text.trim().isNotEmpty
              ? emergencyNameController.text.trim()
              : null,
      emergencyContactPhone:
          emergencyPhoneController.text.trim().isNotEmpty
              ? emergencyPhoneController.text.trim()
              : null,
      isActive: isActive.value,
      createdAt: editingStaff?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  String _generateStaffCode() {
    final now = DateTime.now();
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();

    final initials =
        '${firstName.isNotEmpty ? firstName[0].toUpperCase() : 'X'}'
        '${lastName.isNotEmpty ? lastName[0].toUpperCase() : 'X'}';

    return 'EMP-${now.year}-$initials-${now.millisecond.toString().padLeft(3, '0')}';
  }

  // ✅ CARGA DE EMPLEADO MEJORADA
  void loadStaff(Staff staff) {
    //     print('📝 Cargando datos del empleado: ${staff.fullName}');

    editingStaff = staff;

    // ✅ CARGAR DATOS DE FORMA SEGURA
    firstNameController.text = staff.firstName;
    lastNameController.text = staff.lastName;
    emailController.text = staff.email;
    phoneController.text = staff.phone ?? '';
    identificationController.text = staff.identificationNumber;

    // ✅ ASIGNACIÓN SEGURA PARA OBSERVABLES
    departmentId.value =
        staff.departmentId.isNotEmpty ? staff.departmentId : null;
    positionId.value = staff.positionId.isNotEmpty ? staff.positionId : null;
    // ✅ Cargar especialidad
    especialidadId.value =
        (staff.especialidadId != null && staff.especialidadId!.isNotEmpty)
            ? staff.especialidadId
            : null;
    identificationType.value = staff.identificationType;
    hireDate.value = staff.hireDate;
    photoUrl.value = staff.photoUrl;
    isActive.value = staff.isActive;

    // ✅ CARGAR CAMPOS ADICIONALES SI ES StaffModel
    if (staff is StaffModel) {
      birthDate.value = staff.birthDate;
      addressController.text = staff.address ?? '';
      emergencyNameController.text = staff.emergencyContactName ?? '';
      emergencyPhoneController.text = staff.emergencyContactPhone ?? '';
      salaryController.text = staff.salary?.toString() ?? '';
    }

    // ✅ VALIDAR DESPUÉS DE CARGAR
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!isClosed) _validateForm();
    });
  }

  // ✅ LIMPIEZA DEL FORMULARIO MEJORADA
  void clearForm() {
    //     print('🧹 Limpiando formulario...');

    editingStaff = null;

    // ✅ LIMPIAR TEXT CONTROLLERS
    firstNameController.clear();
    lastNameController.clear();
    emailController.clear();
    phoneController.clear();
    identificationController.clear();
    addressController.clear();
    salaryController.clear();
    emergencyNameController.clear();
    emergencyPhoneController.clear();

    // ✅ RESETEAR OBSERVABLES
    departmentId.value = null;
    positionId.value = null;
    especialidadId.value = null; // ✅ Resetear especialidad
    identificationType.value = IdentificationType.dni;
    hireDate.value = DateTime.now();
    birthDate.value = null;
    photoUrl.value = null;
    isActive.value = true;

    // ✅ LIMPIAR ESTADO DEL FORMULARIO
    formErrors.clear();
    formSuccessful.value = false;

    if (!isClosed) {
      isFormValid.value = false;
    }
  }

  // ✅ GUARDADO DEL EMPLEADO COMPLETAMENTE CORREGIDO
  Future<void> saveStaff() async {
    if (isClosed) return; // ✅ VERIFICACIÓN DE SEGURIDAD

    //     print('💾 Iniciando guardado de empleado...');

    // ✅ FORZAR VALIDACIÓN ANTES DE GUARDAR
    _validateForm();

    if (!isFormValid.value) {
      //       print('❌ Formulario inválido');
      _showValidationDialog();
      return;
    }

    try {
      final staffController = Get.find<StaffController>();
      final staff = toStaff();

      staffController.editingStaff = editingStaff;

      if (editingStaff == null) {
        //         print('📦 Creando nuevo empleado...');
        await staffController.createStaff(staff);
        //         print('✅ Empleado creado exitosamente');
        _showSuccessMessage('Empleado creado exitosamente');
      } else {
        //         print('📝 Actualizando empleado existente...');
        await staffController.updateStaff(staff);
        //         print('✅ Empleado actualizado exitosamente');
        _showSuccessMessage('Empleado actualizado exitosamente');
      }

      // ✅ MARCAR COMO EXITOSO SOLO SI NO HAY ERRORES
      formSuccessful.value = true;
      //       print('✅ Operación completada - formSuccessful = true');
    } catch (e) {
      //       print('❌ Error en saveStaff: $e');
      _handleSaveError(e.toString());
      // ✅ NO marcar como exitoso en caso de error
      formSuccessful.value = false;
    }
  }

  void _showValidationDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Error de Validación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Por favor corrige los siguientes errores:'),
            const SizedBox(height: 10),
            ...formErrors.entries.map(
              (error) => Text(
                '• ${error.value}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    Get.snackbar(
      'Éxito',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green[600],
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }

  void _handleSaveError(String errorMessage) {
    //     print('🔍 Manejando error de guardado: $errorMessage');

    // ✅ LIMPIAR ERRORES DE CAMPOS ESPECÍFICOS
    formErrors.remove('email');
    formErrors.remove('identificationNumber');

    // ✅ PROCESAR ERRORES ESPECÍFICOS
    if (errorMessage.toLowerCase().contains('email') &&
        errorMessage.toLowerCase().contains('registrado')) {
      formErrors['email'] = 'Este email ya está registrado';
      _showFieldError(
        'Email duplicado',
        'Cambie el email e intente nuevamente',
      );
    } else if (errorMessage.toLowerCase().contains('identificación') ||
        errorMessage.toLowerCase().contains('identification')) {
      formErrors['identificationNumber'] = 'Este número ya está registrado';
      _showFieldError(
        'Identificación duplicada',
        'Cambie el número e intente nuevamente',
      );
    } else {
      _showGeneralError(errorMessage);
    }

    // ✅ ACTUALIZAR ESTADO DEL FORMULARIO
    if (!isClosed && formErrors.isNotEmpty) {
      isFormValid.value = false;
    }
  }

  void _showFieldError(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red[600],
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
      icon: const Icon(Icons.error_outline, color: Colors.white),
    );
  }

  void _showGeneralError(String errorMessage) {
    Get.snackbar(
      'Error',
      errorMessage.contains('Exception:')
          ? 'Error técnico. Intente nuevamente'
          : errorMessage,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red[600],
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
      icon: const Icon(Icons.error_outline, color: Colors.white),
    );
  }

  // ✅ MÉTODOS DE DEBUG (OPCIONALES)
  void debugFormState() {
    //     print('📋 DEBUG Form State:');
    //     print('  - isFormValid: ${isFormValid.value}');
    //     print('  - formErrors: $formErrors');
    //     print('  - departmentId: ${departmentId.value}');
    //     print('  - positionId: ${positionId.value}');
  }

  void forceValidation() {
    if (!isClosed) {
      _validateForm();
    }
  }

  @override
  void onClose() {
    //     print('🔄 Cerrando StaffFormController...');

    try {
      // ✅ DISPOSE CONTROLLERS DE FORMA SEGURA
      firstNameController.dispose();
      lastNameController.dispose();
      emailController.dispose();
      phoneController.dispose();
      identificationController.dispose();
      addressController.dispose();
      salaryController.dispose();
      emergencyNameController.dispose();
      emergencyPhoneController.dispose();
    } catch (e) {
      //       print('⚠️ Error disposing controllers: $e');
    }

    super.onClose();
  }
}
