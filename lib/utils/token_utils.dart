import 'dart:convert';
import 'dart:math';
import '../database/database.dart';

/// Генерирует случайный токен для авторизации
String generateToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (i) => random.nextInt(256));
  return base64Url.encode(bytes);
}

/// Генерирует уникальный токен с проверкой в базе данных
/// Повторяет попытки до тех пор, пока не найдет уникальный токен
/// Максимум 10 попыток для предотвращения бесконечного цикла
Future<String> generateUniqueToken() async {
  final conn = await Database.getConnection();
  const maxAttempts = 10;

  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    final token = generateToken();

    // Проверяем, существует ли токен в базе данных
    final result = await conn.execute(
      'SELECT id FROM tokens WHERE token = \$1',
      parameters: [token],
    );

    // Если токен не найден, возвращаем его
    if (result.isEmpty) {
      return token;
    }

    // Если токен найден, генерируем новый
    // В реальности вероятность коллизии крайне мала, но на всякий случай
  }

  // Если после 10 попыток не удалось найти уникальный токен
  // (что практически невозможно), выбрасываем исключение
  throw Exception('Не удалось сгенерировать уникальный токен после $maxAttempts попыток');
}

/// Проверяет, истек ли токен
bool isTokenExpired(DateTime expiresAt) {
  return DateTime.now().isAfter(expiresAt);
}

