class User {
  final int? id;
  final String name;
  final String email;
  final String login;
  final String password;

  User({
    this.id,
    required this.name,
    required this.email,
    required this.login,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'login': login,
      // Пароль не включаем в JSON для безопасности
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int?,
      name: json['name'] as String,
      email: json['email'] as String,
      login: json['login'] as String,
      password: json['password'] as String? ?? '',
    );
  }
}

