class UserSession {
  final String nombreUsuario;
  final String rol;
  final DateTime sessionStart;

  UserSession({
    required this.nombreUsuario,
    required this.rol,
    DateTime? sessionStart,
  }) : sessionStart = sessionStart ?? DateTime.now();

  bool get isAdmin => rol == 'administrador';
}
