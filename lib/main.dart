import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'routes/user_routes.dart';
import 'routes/place_routes.dart';
import 'routes/review_routes.dart';
import 'database/database.dart';

void main() async {
  // Инициализация подключения к БД
  await Database.getConnection();
  print('Подключение к базе данных установлено');

  // Создание роутера и объединение всех роутов
  final router = Router();

  // Подключение роутов
  router.mount('/api', userRoutes());
  router.mount('/api', placeRoutes());
  router.mount('/api', reviewRoutes());

  // Обработчик для корневого пути
  router.get('/', (Request request) {
    return Response.ok(
      'IAM Here Backend API\n\n'
      'Доступные эндпоинты:\n'
      '- POST /api/users - создание пользователя\n'
      '- GET /api/users - получение всех пользователей\n'
      '- GET /api/users/<id> - получение пользователя по ID\n'
      '- PUT /api/users/<id> - обновление пользователя\n'
      '- DELETE /api/users/<id> - удаление пользователя\n\n'
      '- POST /api/places - создание места\n'
      '- GET /api/places - получение всех мест\n'
      '- GET /api/places/<id> - получение места по ID\n'
      '- PUT /api/places/<id> - обновление места\n'
      '- DELETE /api/places/<id> - удаление места\n\n'
      '- POST /api/reviews - создание отзыва\n'
      '- GET /api/reviews - получение всех отзывов\n'
      '- GET /api/reviews/<id> - получение отзыва по ID\n'
      '- PUT /api/reviews/<id> - обновление отзыва\n'
      '- DELETE /api/reviews/<id> - удаление отзыва',
      headers: {'Content-Type': 'text/plain; charset=utf-8'},
    );
  });

  // Добавление CORS заголовков
  final handler = Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
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

