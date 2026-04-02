import 'package:flutter/material.dart';
import '../models/plantilla_model.dart';
import '../models/tag_category_model.dart';
import '../../clientes/models/cliente_model.dart';
import '../services/plantilla_api_service.dart';
import '../services/tags_api_service.dart';
import '../../clientes/services/clientes_api_service.dart';
import '../../servicios/services/servicios_api_service.dart';
import '../../servicios/models/servicio_model.dart';
import '../utils/mappers/tag_engine.dart';

class PlantillaProvider with ChangeNotifier {
  // ==================================================
  // ESTADO
  // ==================================================

  // Plantillas
  List<Plantilla> _plantillas = [];
  bool _isLoadingPlantillas = false;
  String? _plantillasError;

  // Tags
  List<TagCategory> _tagCategories = [];
  bool _isLoadingTags = false;
  String? _tagsError;

  // Clientes
  List<ClienteModel> _clientes = [];
  bool _isLoadingClientes = false;
  String? _clientesError;

  // Plantilla actual (para edición)
  Plantilla? _currentPlantilla;

  // Validación de tags
  Map<String, dynamic>? _validationResult;
  bool _isValidating = false;

  // Preview (vista previa)
  Map<String, dynamic>? _previewResult;
  String? _previewError;
  bool _isGeneratingPreview = false;

  // ==================================================
  // GETTERS
  // ==================================================

  List<Plantilla> get plantillas => _plantillas;
  bool get isLoadingPlantillas => _isLoadingPlantillas;
  String? get plantillasError => _plantillasError;

  List<TagCategory> get tagCategories => _tagCategories;
  bool get isLoadingTags => _isLoadingTags;
  String? get tagsError => _tagsError;

  List<ClienteModel> get clientes => _clientes;
  bool get isLoadingClientes => _isLoadingClientes;
  String? get clientesError => _clientesError;

  Plantilla? get currentPlantilla => _currentPlantilla;

  Map<String, dynamic>? get validationResult => _validationResult;
  bool get isValidating => _isValidating;

  // Preview getters
  Map<String, dynamic>? get previewResult => _previewResult;
  String? get previewError => _previewError;
  bool get isGeneratingPreview => _isGeneratingPreview;

  // ==================================================
  // MÉTODOS - PLANTILLAS
  // ==================================================

  /// Cargar todas las plantillas
  Future<void> loadPlantillas({int? clienteId, int? esGeneral, String? modulo}) async {
    //     print('🔵 [PlantillaProvider] Iniciando loadPlantillas...');
    //     print('🔵 [PlantillaProvider] Parámetros: clienteId=$clienteId, esGeneral=$esGeneral');

    _isLoadingPlantillas = true;
    _plantillasError = null;

    //     print('🔵 [PlantillaProvider] Estado: isLoadingPlantillas=true');
    notifyListeners();

    try {
      //       print('🔵 [PlantillaProvider] Llamando a PlantillaApiService.getPlantillas()...');

      _plantillas = await PlantillaApiService.getPlantillas(
        clienteId: clienteId,
        esGeneral: esGeneral,
        modulo: modulo,
      );

      //       print('✅ [PlantillaProvider] Plantillas cargadas: ${_plantillas.length}');

      _plantillasError = null;

      //       print('🔵 [PlantillaProvider] Limpiando error y actualizando estado...');
    } catch (e) {
      //       print('❌ [PlantillaProvider] Error capturado: $e');
      //       print('❌ [PlantillaProvider] Stack trace: $stackTrace');

      _plantillasError = e.toString();
      _plantillas = [];
    } finally {
      _isLoadingPlantillas = false;

      //       print('🔵 [PlantillaProvider] Estado final: isLoadingPlantillas=false, plantillas.length=${_plantillas.length}, error=$_plantillasError');
      //       print('🔵 [PlantillaProvider] Notificando listeners...');

      notifyListeners();

      //       print('✅ [PlantillaProvider] loadPlantillas completado');
    }
  }

  /// Cargar una plantilla específica
  Future<void> loadPlantilla(int id) async {
    //     print('🔵 [PlantillaProvider] Cargando plantilla ID: $id');

    _isLoadingPlantillas = true;
    _plantillasError = null;
    notifyListeners();

    try {
      _currentPlantilla = await PlantillaApiService.getPlantilla(id);

      //       print('✅ [PlantillaProvider] Plantilla cargada: ${_currentPlantilla?.nombre}');

      _plantillasError = null;
    } catch (e) {
      //       print('❌ [PlantillaProvider] Error: $e');

      _plantillasError = e.toString();
      _currentPlantilla = null;
    } finally {
      _isLoadingPlantillas = false;
      notifyListeners();
    }
  }
  /// Recupera plantillas filtradas para selección (Cliente + Generales)
  Future<List<Plantilla>> fetchTemplatesForSelection({int? clienteId, String? modulo}) async {
    try {
      // 1. Obtener plantillas generales
      final generales = await PlantillaApiService.getPlantillas(esGeneral: 1, modulo: modulo);
      
      // 2. Obtener plantillas específicas del cliente si aplica
      List<Plantilla> especificas = [];
      if (clienteId != null) {
        especificas = await PlantillaApiService.getPlantillas(clienteId: clienteId, esGeneral: 0, modulo: modulo);
      }
      
      // Combinar y retornar (las específicas primero)
      return [...especificas, ...generales];
    } catch (e) {
      debugPrint('Error en fetchTemplatesForSelection: $e');
      rethrow;
    }
  }

  /// Cargar una nueva plantilla vacía para creación

  /// Crear nueva plantilla
  Future<bool> createPlantilla(Plantilla plantilla) async {
    //     print('🔵 [PlantillaProvider] Creando plantilla: ${plantilla.nombre}');

    _isLoadingPlantillas = true;
    _plantillasError = null;
    notifyListeners();

    try {
      final nuevaPlantilla = await PlantillaApiService.createPlantilla(
        plantilla,
      );

      //       print('✅ [PlantillaProvider] Plantilla creada con ID: ${nuevaPlantilla.id}');

      _plantillas.insert(0, nuevaPlantilla);
      _currentPlantilla = nuevaPlantilla;
      _plantillasError = null;

      notifyListeners();
      return true;
    } catch (e) {
      //       print('❌ [PlantillaProvider] Error: $e');

      _plantillasError = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoadingPlantillas = false;
      notifyListeners();
    }
  }

  /// Actualizar plantilla existente
  Future<bool> updatePlantilla(Plantilla plantilla) async {
    //     print('🔵 [PlantillaProvider] Actualizando plantilla ID: ${plantilla.id}');

    _isLoadingPlantillas = true;
    _plantillasError = null;
    notifyListeners();

    try {
      final plantillaActualizada = await PlantillaApiService.updatePlantilla(
        plantilla,
      );

      //       print('✅ [PlantillaProvider] Plantilla actualizada: ${plantillaActualizada.nombre}');

      // Actualizar en la lista
      final index = _plantillas.indexWhere((p) => p.id == plantilla.id);
      if (index != -1) {
        _plantillas[index] = plantillaActualizada;
      }

      _currentPlantilla = plantillaActualizada;
      _plantillasError = null;

      notifyListeners();
      return true;
    } catch (e) {
      //       print('❌ [PlantillaProvider] Error: $e');

      _plantillasError = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoadingPlantillas = false;
      notifyListeners();
    }
  }

  /// Eliminar plantilla
  Future<bool> deletePlantilla(int id) async {
    //     print('🔵 [PlantillaProvider] Eliminando plantilla ID: $id');

    _isLoadingPlantillas = true;
    _plantillasError = null;
    notifyListeners();

    try {
      await PlantillaApiService.deletePlantilla(id);

      //       print('✅ [PlantillaProvider] Plantilla eliminada');

      // Remover de la lista
      _plantillas.removeWhere((p) => p.id == id);

      if (_currentPlantilla?.id == id) {
        _currentPlantilla = null;
      }

      _plantillasError = null;
      notifyListeners();
      return true;
    } catch (e) {
      //       print('❌ [PlantillaProvider] Error: $e');

      _plantillasError = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoadingPlantillas = false;
      notifyListeners();
    }
  }

  /// Establecer plantilla actual para edición
  void setCurrentPlantilla(Plantilla? plantilla) {
    //     print('🔵 [PlantillaProvider] setCurrentPlantilla: ${plantilla?.nombre ?? "null"}');
    _currentPlantilla = plantilla;
    notifyListeners();
  }

  /// Crear nueva plantilla vacía
  void createNewPlantilla({String modulo = 'servicios'}) {
    //     print('🔵 [PlantillaProvider] Creando nueva plantilla vacía para módulo: $modulo');
    _currentPlantilla = Plantilla(
      nombre: '',
      modulo: modulo,
      esGeneral: false,
      contenidoHtml: '',
    );
    notifyListeners();
  }

  /// Actualizar campo de la plantilla actual
  void updateCurrentPlantillaField({
    String? nombre,
    String? modulo,
    int? clienteId,
    bool? esGeneral,
    String? contenidoHtml,
  }) {
    if (_currentPlantilla == null) return;

    _currentPlantilla = _currentPlantilla!.copyWith(
      nombre: nombre ?? _currentPlantilla!.nombre,
      modulo: modulo ?? _currentPlantilla!.modulo,
      clienteId: clienteId ?? _currentPlantilla!.clienteId,
      esGeneral: esGeneral ?? _currentPlantilla!.esGeneral,
      contenidoHtml: contenidoHtml ?? _currentPlantilla!.contenidoHtml,
    );

    notifyListeners();
  }

  // ==================================================
  // MÉTODOS - TAGS
  // ==================================================

  /// Cargar tags disponibles
  Future<void> loadTags({String? modulo}) async {
    //     print('🔵 [PlantillaProvider] Cargando tags para módulo: $modulo');

    _isLoadingTags = true;
    _tagsError = null;
    notifyListeners();

    try {
      _tagCategories = await TagsApiService.getTags(modulo: modulo);

      //       print('✅ [PlantillaProvider] Tags cargados: ${_tagCategories.length} categorías');

      _tagsError = null;
    } catch (e) {
      //       print('❌ [PlantillaProvider] Error: $e');

      _tagsError = e.toString();
      _tagCategories = [];
    } finally {
      _isLoadingTags = false;
      notifyListeners();
    }
  }

  /// Validar tags en el HTML (usa local primero para rapidez)
  Future<void> validateTags(String contenidoHtml) async {
    //     print('🔵 [PlantillaProvider] Validando tags...');

    _isValidating = true;
    notifyListeners();

    try {
      // 1. Validación Local (Rápida e instantánea)
      final localResult = TagEngine.validateTagsLocally(
        contenidoHtml,
        _tagCategories,
      );

      // Guardar resultado local inicial
      _validationResult = localResult;
      notifyListeners();

      // 2. Validación Backend (Opcional, para lógica compleja)
      try {
        final backendResult = await TagsApiService.validateTags(contenidoHtml);
        // Si el backend responde, usamos sus datos que son más precisos (sugerencias, etc)
        _validationResult = backendResult;
      } catch (e) {
        debugPrint('⚠️ Error en validación backend, se mantiene local: $e');
      }

    } catch (e) {
      //       print('❌ [PlantillaProvider] Error: $e');
      _validationResult = {
        'es_valido': false, 
        'error': e.toString(),
        'tags_invalidos': []
      };
    } finally {
      _isValidating = false;
      notifyListeners();
    }
  }

  /// Limpiar resultado de validación
  void clearValidationResult() {
    //     print('🔵 [PlantillaProvider] Limpiando resultado de validación');
    _validationResult = null;
    notifyListeners();
  }

  // ==================================================
  // MÉTODOS - CLIENTES
  // ==================================================

  /// Cargar clientes
  Future<void> loadClientes({String? busqueda, bool activosSolo = true}) async {
    //     print('🔵 [PlantillaProvider] Cargando clientes...');

    _isLoadingClientes = true;
    _clientesError = null;
    notifyListeners();

    try {
      _clientes = await ClientesApiService.listarClientes(
        search: busqueda,
        estado: activosSolo ? 1 : null,
        limit: 1000,
      );

      //       print('✅ [PlantillaProvider] Clientes cargados: ${_clientes.length}');

      _clientesError = null;
    } catch (e) {
      //       print('❌ [PlantillaProvider] Error: $e');

      _clientesError = e.toString();
      _clientes = [];
    } finally {
      _isLoadingClientes = false;
      notifyListeners();
    }
  }

  /// Buscar cliente por ID
  ClienteModel? getClienteById(int id) {
    try {
      return _clientes.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // ==================================================
  // MÉTODOS - UTILIDADES
  // ==================================================

  /// Limpiar errores
  void clearErrors() {
    //     print('🔵 [PlantillaProvider] Limpiando errores');
    _plantillasError = null;
    _tagsError = null;
    _clientesError = null;
    notifyListeners();
  }

  /// Reiniciar provider
  void reset() {
    //     print('🔵 [PlantillaProvider] Reiniciando provider');

    _plantillas = [];
    _tagCategories = [];
    _clientes = [];
    _currentPlantilla = null;
    _validationResult = null;

    _isLoadingPlantillas = false;
    _isLoadingTags = false;
    _isLoadingClientes = false;
    _isValidating = false;

    _plantillasError = null;
    _tagsError = null;
    _clientesError = null;

    notifyListeners();
  }

  /// Vista previa de plantilla
  Future<Map<String, dynamic>?> getPreview(int servicioId, {int? plantillaId}) async {
    //     print('🔵 [PlantillaProvider] getPreview para servicio: $servicioId');

    try {
      return await PlantillaApiService.previewPlantilla(servicioId, plantillaId: plantillaId);
    } catch (e) {
      //       print('❌ [PlantillaProvider] Error: $e');
      return null;
    }
  }

  /// Generar vista previa y mantener estado/errores
  Future<void> generatePreview(int servicioId, {int? plantillaId}) async {
    //     print('🔵 [PlantillaProvider] Generando preview para servicio: $servicioId');

    _isGeneratingPreview = true;
    _previewError = null;
    _previewResult = null;
    notifyListeners();

    try {
      final result = await PlantillaApiService.previewPlantilla(servicioId, plantillaId: plantillaId);

      //       print('✅ [PlantillaProvider] Preview generado exitosamente');
      //       print('🔵 [PlantillaProvider] Result keys: ${result.keys}');

      _previewResult = result;
      _previewError = null;
    } catch (e) {
      //       print('❌ [PlantillaProvider] Error: $e');

      _previewError = e.toString();
      _previewResult = null;
    } finally {
      _isGeneratingPreview = false;
      notifyListeners();
    }
  }

  /// Generar vista previa usando número de servicio (o_servicio)
  /// y el HTML de la plantilla actualmente editada
  Future<void> generatePreviewByOrden(String oServicio) async {
    //     print('🔵 [PlantillaProvider] Generando preview por o_servicio: $oServicio');
    _isGeneratingPreview = true;
    _previewError = null;
    _previewResult = null;
    notifyListeners();

    try {
      final html = _currentPlantilla?.contenidoHtml ?? '';
      if (html.trim().isEmpty) {
        throw Exception('No hay contenido HTML en la plantilla actual');
      }

      final result = await PlantillaApiService.previewPlantillaPorOrden(
        oServicio: oServicio,
        contenidoHtml: html,
      );

      //       print('✅ [PlantillaProvider] Preview generado (por orden)');
      _previewResult = result;
      _previewError = null;
    } catch (e) {
      //       print('❌ [PlantillaProvider] Error con o_servicio directo: $e');
      // Fallback: intentar resolver servicio_id por búsqueda y usar preview clásico
      try {
        //         print('🔄 [PlantillaProvider] Intentando fallback: buscar servicio por o_servicio "$oServicio"');
        final r = await ServiciosApiService.listarServicios(
          pagina: 1,
          limite: 1,
          buscar: oServicio,
        );
        final servicios = (r['servicios'] as List<ServicioModel>);
        if (servicios.isNotEmpty && servicios.first.id != null) {
          final servicioId = servicios.first.id!;
          //           print('🔄 [PlantillaProvider] Encontrado servicio_id=$servicioId, generando preview clásico');
          final result = await PlantillaApiService.previewPlantilla(servicioId);
          _previewResult = result;
          _previewError = null;
          //           print('✅ [PlantillaProvider] Preview generado por fallback (servicio_id)');
        } else {
          throw Exception('No se encontró servicio para "$oServicio"');
        }
      } catch (fallbackErr) {
        //         print('❌ [PlantillaProvider] Fallback falló: $fallbackErr');
        _previewError = fallbackErr.toString();
        _previewResult = null;
      }
    } finally {
      _isGeneratingPreview = false;
      notifyListeners();
    }
  }

  /// Limpiar estado de vista previa
  void clearPreview() {
    //     print('🔵 [PlantillaProvider] Limpiando preview');
    _previewResult = null;
    _previewError = null;
    notifyListeners();
  }
}
