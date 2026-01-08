import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'routes/user_routes.dart';
import 'routes/place_routes.dart';
import 'routes/review_routes.dart';
import 'routes/auth_routes.dart';
import 'middleware/auth_middleware.dart';
import 'database/database.dart';

void main() async {
  // Инициализация подключения к БД
  await Database.getConnection();
  print('Подключение к базе данных установлено');

  // Создание роутера и объединение всех роутов
  final router = Router();

  // Подключение роутов
  router.mount('/api', authRoutes()); // Роуты авторизации (публичные)
  router.mount('/api', userRoutes());
  router.mount('/api', placeRoutes());
  router.mount('/api', reviewRoutes());

  // Обработчик для корневого пути
  router.get('/', (Request request) {
    return Response.ok(
      'IAM Here Backend API\n\n'
      'Авторизация:\n'
      '- POST /api/auth/login - вход (login, password) - возвращает Bearer Token\n'
      '- POST /api/auth/logout - выход (требует Bearer Token)\n'
      '- GET /api/auth/me - информация о текущем пользователе (требует Bearer Token)\n\n'
      'Пользователи:\n'
      '- POST /api/users - создание пользователя\n'
      '- GET /api/users - получение всех пользователей\n'
      '- GET /api/users/<id> - получение пользователя по ID\n'
      '- PUT /api/users/<id> - обновление пользователя\n'
      '- DELETE /api/users/<id> - удаление пользователя\n\n'
      'Места:\n'
      '- POST /api/places - создание места\n'
      '- GET /api/places - получение всех мест\n'
      '- GET /api/places/<id> - получение места по ID\n'
      '- PUT /api/places/<id> - обновление места\n'
      '- DELETE /api/places/<id> - удаление места\n\n'
      'Отзывы:\n'
      '- POST /api/reviews - создание отзыва\n'
      '- GET /api/reviews - получение всех отзывов\n'
      '- GET /api/reviews/<id> - получение отзыва по ID\n'
      '- PUT /api/reviews/<id> - обновление отзыва\n'
      '- DELETE /api/reviews/<id> - удаление отзыва\n\n'
      'Примечание: Большинство эндпоинтов требуют Bearer Token в заголовке Authorization',
      headers: {'Content-Type': 'text/plain; charset=utf-8'},
    );
  });

  // Добавление middleware
  final handler = Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addMiddleware(authMiddleware())
      .addHandler(router);

  // Запуск сервера
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    port,
  );

  print('Сервер запущен на http://${server.address.host}:${server.port}');

  // Обработка завершения работы
  ProcessSignal.sigint.watch().listen((signal) async {
    print('\nЗавершение работы сервера...');
    await Database.close();
    await server.close(force: true);
    exit(0);
  });
}

