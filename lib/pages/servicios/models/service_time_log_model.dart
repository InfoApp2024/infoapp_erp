import 'package:intl/intl.dart';

class ServiceTimeLogModel {
  final int? id;
  final int serviceId;
  final int? fromStatusId;
  final String? fromStatusName;
  final int toStatusId;
  final String toStatusName;
  final int userId;
  final String? userName;
  final int durationSeconds;
  final String timestamp;
  final String? createdAt;

  ServiceTimeLogModel({
    this.id,
    required this.serviceId,
    this.fromStatusId,
    this.fromStatusName,
    required this.toStatusId,
    required this.toStatusName,
    required this.userId,
    this.userName,
    required this.durationSeconds,
    required this.timestamp,
    this.createdAt,
  });

  factory ServiceTimeLogModel.fromJson(Map<String, dynamic> json) {
    return ServiceTimeLogModel(
      id: json['id'],
      serviceId: json['service_id'],
      fromStatusId: json['from_status_id'],
      fromStatusName: json['from_status_name'],
      toStatusId: json['to_status_id'],
      toStatusName: json['to_status_name'],
      userId: json['user_id'],
      userName: json['user_name'],
      durationSeconds: json['duration_seconds'] ?? 0,
      timestamp: json['timestamp'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_id': serviceId,
      'from_status_id': fromStatusId,
      'to_status_id': toStatusId,
      'user_id': userId,
      'duration_seconds': durationSeconds,
      'timestamp': timestamp,
    };
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '0m';

    final duration = Duration(seconds: durationSeconds);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  String get formattedDateTime {
    try {
      // Si no tiene Z y suponemos que el backend envía UTC, se la agregamos
      String ts = timestamp;
      // El backend envía hora local de Bogotá.
      // Si intentamos parsearla con 'Z' o ISO8601 incompleto, Dart puede confundirse.
      if (!ts.contains('T')) {
        ts = ts.replaceAll(' ', 'T');
      }
      return DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.parse(ts));
    } catch (e) {
      return timestamp;
    }
  }
}
