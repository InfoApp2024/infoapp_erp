class AuthCredentials {
  final String usuario;
  final String password;

  AuthCredentials({required this.usuario, required this.password});

  Map<String, dynamic> toJson() => {
        'usuario': usuario,
        'password': password,
      };
}
