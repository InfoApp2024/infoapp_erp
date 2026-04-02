
/// Representa un upload pendiente de foto de geocerca
class PendingUpload {
  final String id; // UUID único
  final int geocercaId;
  final String event; // 'ingreso' o 'salida'
  final DateTime detectionTime; // Tiempo de detección GPS
  final DateTime captureTime; // Tiempo de captura de foto
  final String photoPath; // Ruta local de la foto comprimida
  final int retryCount;
  final DateTime lastAttempt;

  PendingUpload({
    required this.id,
    required this.geocercaId,
    required this.event,
    required this.detectionTime,
    required this.captureTime,
    required this.photoPath,
    this.retryCount = 0,
    required this.lastAttempt,
  });

  /// Crea una copia con campos actualizados
  PendingUpload copyWith({
    int? retryCount,
    DateTime? lastAttempt,
  }) {
    return PendingUpload(
      id: id,
      geocercaId: geocercaId,
      event: event,
      detectionTime: detectionTime,
      captureTime: captureTime,
      photoPath: photoPath,
      retryCount: retryCount ?? this.retryCount,
      lastAttempt: lastAttempt ?? this.lastAttempt,
    );
  }

  /// Serializa a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'geocerca_id': geocercaId,
      'event': event,
      'detection_time': detectionTime.toIso8601String(),
      'capture_time': captureTime.toIso8601String(),
      'photo_path': photoPath,
      'retry_count': retryCount,
      'last_attempt': lastAttempt.toIso8601String(),
    };
  }

  /// Deserializa desde JSON
  factory PendingUpload.fromJson(Map<String, dynamic> json) {
    return PendingUpload(
      id: json['id'] as String,
      geocercaId: json['geocerca_id'] as int,
      event: json['event'] as String,
      detectionTime: DateTime.parse(json['detection_time'] as String),
      captureTime: DateTime.parse(json['capture_time'] as String),
      photoPath: json['photo_path'] as String,
      retryCount: json['retry_count'] as int? ?? 0,
      lastAttempt: DateTime.parse(json['last_attempt'] as String),
    );
  }

  @override
  String toString() {
    return 'PendingUpload(id: $id, geocerca: $geocercaId, event: $event, retries: $retryCount)';
  }
}
