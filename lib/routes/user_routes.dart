import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database.dart';
import '../models/user.dart';
import 'dart:convert';

Handler userRoutes() {
  final router = Router();

  // Создание пользователя
  router.post('/users', (Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final user = User.fromJson(json);

      final conn = await Database.getConnection();
      final result = await conn.execute(
        'INSERT INTO users (name, email, login, password) VALUES (\$1, \$2, \$3, \$4) RETURNING id',
        parameters: [
          user.name,
          user.email,
          user.login,
          user.password,
        ],
      );

      final userId = result.first[0] as int;
      final createdUser = User(
        id: userId,
        name: user.name,
        email: user.email,
        login: user.login,
        password: '',
      );

      return Response.ok(
        jsonEncode(createdUser.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Получение всех пользователей
  router.get('/users', (Request request) async {
    try {
      final conn = await Database.getConnection();
      final result = await conn.execute('SELECT * FROM users');

      final users = result.map((row) {
        return User(
          id: row[0] as int,
          name: row[1] as String,
          email: row[2] as String,
          login: row[3] as String,
          password: '',
        ).toJson();
      }).toList();

      return Response.ok(
        jsonEncode(users),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Получение пользователя по ID
  router.get('/users/<id>', (Request request, String id) async {
    try {
      final userId = int.parse(id);
      final conn = await Database.getConnection();
      final result = await conn.execute(
        'SELECT * FROM users WHERE id = \$1',
        parameters: [userId],
      );

      if (result.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Пользователь не найден'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final row = result.first;
      final user = User(
        id: row[0] as int,
        name: row[1] as String,
        email: row[2] as String,
        login: row[3] as String,
        password: '',
      );

      return Response.ok(
        jsonEncode(user.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Обновление пользователя
  router.put('/users/<id>', (Request request, String id) async {
    try {
      final userId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final conn = await Database.getConnection();

      // Проверяем существование пользователя
      final checkResult = await conn.execute(
        'SELECT id FROM users WHERE id = \$1',
        parameters: [userId],
      );

      if (checkResult.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Пользователь не найден'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await conn.execute(
        'UPDATE users SET name = \$1, email = \$2, login = \$3, password = \$4 WHERE id = \$5',
        parameters: [
          json['name'] as String,
          json['email'] as String,
          json['login'] as String,
          json['password'] as String? ?? '',
          userId,
        ],
      );

      final updatedUser = User(
        id: userId,
        name: json['name'] as String,
        email: json['email'] as String,
        login: json['login'] as String,
        password: '',
      );

      return Response.ok(
        jsonEncode(updatedUser.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Удаление пользователя
  router.delete('/users/<id>', (Request request, String id) async {
    try {
      final userId = int.parse(id);
      final conn = await Database.getConnection();

      final result = await conn.execute(
        'DELETE FROM users WHERE id = \$1 RETURNING id',
        parameters: [userId],
      );

      if (result.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Пользователь не найден'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'message': 'Пользователь удален'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  return router.call;
}

