import '../../../../core/enums/modulo_enum.dart';
import '../workflow/estado_workflow_service.dart';

/// Validador para aplicar reglas de negocio a las transiciones de estado.
class TransicionValidator {
  static final EstadoWorkflowService _workflowService = EstadoWorkflowService();

  /// Verifica si una transición de estado está permitida.
  /// Devuelve un mensaje de error si no está permitida, o null si es válida.
  static Future<String?> puedeTransicionar({
    required String estadoOrigen,
    required String estadoDestino,
    ModuloEnum modulo = ModuloEnum.servicios,
  }) async {
    // Asegurar que el workflow esté cargado
    await _workflowService.ensureLoaded(modulo: modulo);

    final permitida = _workflowService.canTransition(estadoOrigen, estadoDestino, modulo: modulo);

    if (!permitida) {
      return 'La transición de "$estadoOrigen" a "$estadoDestino" no está permitida.';
    }

    return null;
  }

  /// Obtiene los nombres de los estados hacia los cuales se puede transicionar.
  static Future<List<String>> obtenerTransicionesPermitidas({
    required String estadoActual,
    ModuloEnum modulo = ModuloEnum.servicios,
  }) async {
    await _workflowService.ensureLoaded(modulo: modulo);
    return _workflowService.nextStates(estadoActual, modulo: modulo);
  }
}
