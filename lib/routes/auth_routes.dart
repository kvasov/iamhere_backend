import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database.dart';
import '../utils/token_utils.dart';
import 'dart:convert';

Handler authRoutes() {
  final router = Router();

  // Авторизация (login)
  router.post('/auth/login', (Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final login = json['login'] as String?;
      final password = json['password'] as String?;

      if (login == null || password == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Требуются поля: login и password'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final conn = await Database.getConnection();

      // Проверяем учетные данные пользователя
      final result = await conn.execute(
        'SELECT id, name, email, login, password FROM users WHERE login = \$1',
        parameters: [login],
      );

      if (result.isEmpty) {
        return Response(
          401,
          body: jsonEncode({'error': 'Неверный логин или пароль'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final row = result.first;
      final storedPassword = row[4] as String;

      // Проверяем пароль (в реальном приложении используйте хеширование!)
      if (password != storedPassword) {
        return Response(
          401,
          body: jsonEncode({'error': 'Неверный логин или пароль'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final userId = row[0] as int;

      // Удаляем старые токены пользователя (опционально, можно оставить несколько)
      await conn.execute(
        'DELETE FROM tokens WHERE user_id = \$1',
        parameters: [userId],
      );

      // Генерируем уникальный токен с проверкой в базе данных
      final token = await generateUniqueToken();
      final expiresAt = DateTime.now().add(const Duration(days: 30)); // Токен действителен 30 дней

      // Сохраняем токен в базе данных
      await conn.execute(
        'INSERT INTO tokens (user_id, token, expires_at) VALUES (\$1, \$2, \$3)',
        parameters: [userId, token, expiresAt],
      );

      return Response.ok(
        jsonEncode({
          'token': token,
          'expires_at': expiresAt.toIso8601String(),
          'user': {
            'id': userId,
            'name': row[1] as String,
            'email': row[2] as String,
            'login': row[3] as String,
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Выход (logout)
  router.post('/auth/logout', (Request request) async {
    try {
      final authHeader = request.headers['authorization'] ?? '';

      if (!authHeader.startsWith('Bearer ')) {
        return Response(
          401,
          body: jsonEncode({'error': 'Требуется авторизация'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final token = authHeader.substring(7);

      final conn = await Database.getConnection();

      // Удаляем токен из базы данных
      final result = await conn.execute(
        'DELETE FROM tokens WHERE token = \$1 RETURNING id',
        parameters: [token],
      );

      if (result.isEmpty) {
        return Response(
          401,
          body: jsonEncode({'error': 'Токен не найден'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'message': 'Выход выполнен успешно'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Проверка токена (получение информации о текущем пользователе)
  router.get('/auth/me', (Request request) async {
    try {
      final authHeader = request.headers['authorization'] ?? '';

      if (!authHeader.startsWith('Bearer ')) {
        return Response(
          401,
          body: jsonEncode({'error': 'Требуется авторизация'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final token = authHeader.substring(7);

      final conn = await Database.getConnection();

      // Получаем информацию о пользователе по токену
      final result = await conn.execute(
        '''
        SELECT u.id, u.name, u.email, u.login, t.expires_at
        FROM tokens t
        INNER JOIN users u ON t.user_id = u.id
        WHERE t.token = \$1
        ''',
        parameters: [token],
      );

      if (result.isEmpty) {
        return Response(
          401,
          body: jsonEncode({'error': 'Недействительный токен'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final row = result.first;
      final expiresAt = row[4] as DateTime;

      if (isTokenExpired(expiresAt)) {
        return Response(
          401,
          body: jsonEncode({'error': 'Токен истек'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'user': {
            'id': row[0] as int,
            'name': row[1] as String,
            'email': row[2] as String,
            'login': row[3] as String,
          },
          'expires_at': expiresAt.toIso8601String(),
        }),
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

