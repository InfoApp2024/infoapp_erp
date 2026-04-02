import 'dart:convert';

class EstadoDef {
  final String id;
  final String nombre;
  final String? colorHex;

  const EstadoDef({required this.id, required this.nombre, this.colorHex});

  factory EstadoDef.fromJson(Map<String, dynamic> json) {
    return EstadoDef(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      colorHex: json['colorHex'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        if (colorHex != null) 'colorHex': colorHex,
      };
}

class WorkflowTransicionDef {
  final String from;
  final String to;
  final int? toId; // NEW: ID numérico del estado destino
  final String? nombre;
  final String? triggerCode;
  final String? toEstadoBase; // âœ… NUEVO: Estado base para semÃ¡ntica de negocio

  const WorkflowTransicionDef({
    required this.from,
    required this.to,
    this.toId,
    this.nombre,
    this.triggerCode,
    this.toEstadoBase,
  });

  factory WorkflowTransicionDef.fromJson(Map<String, dynamic> json) {
    return WorkflowTransicionDef(
      from: json['from'] as String,
      to: json['to'] as String,
      toId: (json['toId'] ?? json['to_id']) as int?,
      nombre: json['nombre'] as String?,
      triggerCode: (json['triggerCode'] ?? json['trigger_code']) as String?,
      toEstadoBase: (json['toEstadoBase'] ?? json['to_estado_base']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        if (toId != null) 'toId': toId,
        if (nombre != null) 'nombre': nombre,
        if (triggerCode != null) 'triggerCode': triggerCode,
        if (toEstadoBase != null) 'toEstadoBase': toEstadoBase,
      };
}

class WorkflowDef {
  final bool allowUnconfiguredTransitions;
  final List<EstadoDef> estados;
  final List<WorkflowTransicionDef> transiciones;

  const WorkflowDef({
    required this.allowUnconfiguredTransitions,
    required this.estados,
    required this.transiciones,
  });

  factory WorkflowDef.fromJson(Map<String, dynamic> json) {
    final estadosJson = json['estados'] as List<dynamic>? ?? const [];
    final transJson = json['transiciones'] as List<dynamic>? ?? const [];
    return WorkflowDef(
      allowUnconfiguredTransitions:
          (json['allowUnconfiguredTransitions'] as bool?) ?? true,
      estados: estadosJson
          .map((e) => EstadoDef.fromJson(e as Map<String, dynamic>))
          .toList(),
      transiciones: transJson
          .map((t) => WorkflowTransicionDef.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'allowUnconfiguredTransitions': allowUnconfiguredTransitions,
        'estados': estados.map((e) => e.toJson()).toList(),
        'transiciones': transiciones.map((t) => t.toJson()).toList(),
      };

  static WorkflowDef fromJsonString(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    return WorkflowDef.fromJson(data);
  }
}
