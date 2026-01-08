import 'package:shelf/shelf.dart';
import '../database/database.dart';
import '../utils/token_utils.dart';
import 'dart:convert';

/// Middleware для проверки Bearer Token авторизации
/// Добавляет userId в контекст запроса, если токен валиден
Middleware authMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      // Пропускаем публичные маршруты
      final path = request.url.path;
      // Пропускаем маршруты авторизации (auth/login, auth/logout, auth/me)
      // и корневой путь
      if (path.contains('/auth/') || path == '' || path == '/') {
        return await innerHandler(request);
      }

      // Извлекаем токен из заголовка Authorization
      final authHeader = request.headers['authorization'] ?? '';

      if (!authHeader.startsWith('Bearer ')) {
        return Response(
          401,
          body: jsonEncode({'error': 'Требуется авторизация. Используйте формат: Bearer <token>'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final token = authHeader.substring(7); // Убираем "Bearer "

      try {
        final conn = await Database.getConnection();

        // Проверяем токен в базе данных
        final result = await conn.execute(
          '''
          SELECT t.user_id, t.expires_at, u.id, u.name, u.email, u.login
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
        final userId = row[0] as int;
        final expiresAt = row[1] as DateTime;

        // Проверяем срок действия токена
        if (isTokenExpired(expiresAt)) {
          // Удаляем истекший токен
          await conn.execute(
            'DELETE FROM tokens WHERE token = \$1',
            parameters: [token],
          );

          return Response(
            401,
            body: jsonEncode({'error': 'Токен истек'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // Добавляем информацию о пользователе в контекст запроса
        final updatedRequest = request.change(
          context: {
            ...request.context,
            'userId': userId,
            'user': {
              'id': userId,
              'name': row[3] as String,
              'email': row[4] as String,
              'login': row[5] as String,
            },
          },
        );

        return await innerHandler(updatedRequest);
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Ошибка проверки авторизации: ${e.toString()}'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}

/// Получает ID пользователя из контекста запроса
int? getUserId(Request request) {
  return request.context['userId'] as int?;
}

/// Получает информацию о пользователе из контекста запроса
Map<String, dynamic>? getUser(Request request) {
  return request.context['user'] as Map<String, dynamic>?;
}

