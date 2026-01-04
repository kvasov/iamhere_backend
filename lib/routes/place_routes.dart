import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:path/path.dart' as path;
import 'package:postgres/postgres.dart';
import '../database/database.dart';
import '../models/place.dart';
import '../models/photo.dart';
import 'dart:convert';
import 'dart:io';

Handler placeRoutes() {
  final router = Router();

  // Создание места с фотографиями
  router.post('/places', (Request request) async {
    try {
      // Проверяем Content-Type
      final contentType = request.headers['content-type'] ?? '';
      if (!contentType.contains('multipart/form-data')) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Ожидается multipart/form-data'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final uploadsDir = Directory('uploads');
      if (!await uploadsDir.exists()) {
        await uploadsDir.create(recursive: true);
      }

      double? latitude;
      double? longitude;
      String? country;
      String? address;
      String? name;
      final List<String> photoPaths = [];

      // Парсим multipart данные
      final multipartRequest = request.multipart();
      if (multipartRequest == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Не удалось распарсить multipart запрос'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Обрабатываем все части multipart запроса
      await for (final part in multipartRequest.parts) {
        // Получаем имя поля из content-disposition заголовка
        final contentDisposition = part.headers['content-disposition'] ?? '';
        final nameMatch = RegExp(r'name="([^"]+)"').firstMatch(contentDisposition);
        final fieldName = nameMatch?.group(1);

        if (fieldName == 'latitude') {
          latitude = double.parse(await part.readString());
        } else if (fieldName == 'longitude') {
          longitude = double.parse(await part.readString());
        } else if (fieldName == 'country') {
          country = await part.readString();
        } else if (fieldName == 'address') {
          address = await part.readString();
        } else if (fieldName == 'name') {
          name = await part.readString();
        } else if (fieldName == 'photos') {
          // Проверяем, является ли это файлом (есть filename в content-disposition)
          final filenameMatch = RegExp(r'filename="([^"]+)"').firstMatch(contentDisposition);
          final fileName = filenameMatch?.group(1) ?? 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = path.join('uploads', '${DateTime.now().millisecondsSinceEpoch}_$fileName');
          final file = File(filePath);
          await file.create(recursive: true);
          await part.pipe(file.openWrite());
          photoPaths.add(filePath);
        }
      }

      // Валидация обязательных полей
      if (latitude == null || longitude == null || country == null || address == null || name == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Отсутствуют обязательные поля: latitude, longitude, country, address, name'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final conn = await Database.getConnection();

      // Создаем место
      final result = await conn.execute(
        'INSERT INTO places (latitude, longitude, country, address, name) VALUES (\$1, \$2, \$3, \$4, \$5) RETURNING id',
        parameters: [
          latitude,
          longitude,
          country,
          address,
          name,
        ],
      );

      final placeId = result.first[0] as int;

      // Сохраняем фотографии
      final List<Photo> savedPhotos = [];
      for (final photoPath in photoPaths) {
        // Проверяем, существует ли уже такая фотография
        var photoResult = await conn.execute(
          'SELECT id FROM photos WHERE path = \$1',
          parameters: [photoPath],
        );

        int photoId;
        if (photoResult.isEmpty) {
          // Создаем новую запись о фотографии
          final newPhotoResult = await conn.execute(
            'INSERT INTO photos (path) VALUES (\$1) RETURNING id',
            parameters: [photoPath],
          );
          photoId = newPhotoResult.first[0] as int;
        } else {
          photoId = photoResult.first[0] as int;
        }

        // Связываем фотографию с местом
        await conn.execute(
          'INSERT INTO photo_places (place_id, image_id) VALUES (\$1, \$2) ON CONFLICT DO NOTHING',
          parameters: [placeId, photoId],
        );

        savedPhotos.add(Photo(id: photoId, path: photoPath));
      }

      final createdPlace = Place(
        id: placeId,
        latitude: latitude,
        longitude: longitude,
        country: country,
        address: address,
        name: name,
        photos: savedPhotos,
      );

      return Response.ok(
        jsonEncode(createdPlace.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Вспомогательная функция для получения фотографий места
  Future<List<Photo>> _getPlacePhotos(Connection conn, int placeId) async {
    final photosResult = await conn.execute('''
      SELECT p.id, p.path
      FROM photos p
      INNER JOIN photo_places pp ON p.id = pp.image_id
      WHERE pp.place_id = \$1
    ''', parameters: [placeId]);

    return photosResult.map((row) {
      return Photo(
        id: row[0] as int,
        path: row[1] as String,
      );
    }).toList();
  }

  // Получение всех мест
  router.get('/places', (Request request) async {
    try {
      final conn = await Database.getConnection();
      final result = await conn.execute('SELECT * FROM places');

      final places = await Future.wait(result.map((row) async {
        final placeId = row[0] as int;
        final photos = await _getPlacePhotos(conn, placeId);
        return Place(
          id: placeId,
          latitude: (row[1] as num).toDouble(),
          longitude: (row[2] as num).toDouble(),
          country: row[3] as String,
          address: row[4] as String,
          name: row[5] as String,
          photos: photos,
        ).toJson();
      }));

      return Response.ok(
        jsonEncode(places),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Получение места по ID
  router.get('/places/<id>', (Request request, String id) async {
    try {
      final placeId = int.parse(id);
      final conn = await Database.getConnection();
      final result = await conn.execute(
        'SELECT * FROM places WHERE id = \$1',
        parameters: [placeId],
      );

      if (result.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Место не найдено'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final row = result.first;
      final photos = await _getPlacePhotos(conn, placeId);
      final place = Place(
        id: row[0] as int,
        latitude: (row[1] as num).toDouble(),
        longitude: (row[2] as num).toDouble(),
        country: row[3] as String,
        address: row[4] as String,
        name: row[5] as String,
        photos: photos,
      );

      return Response.ok(
        jsonEncode(place.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Обновление места
  router.put('/places/<id>', (Request request, String id) async {
    try {
      final placeId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final conn = await Database.getConnection();

      // Проверяем существование места
      final checkResult = await conn.execute(
        'SELECT id FROM places WHERE id = \$1',
        parameters: [placeId],
      );

      if (checkResult.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Место не найдено'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await conn.execute(
        'UPDATE places SET latitude = \$1, longitude = \$2, country = \$3, address = \$4, name = \$5 WHERE id = \$6',
        parameters: [
          (json['latitude'] as num).toDouble(),
          (json['longitude'] as num).toDouble(),
          json['country'] as String,
          json['address'] as String,
          json['name'] as String,
          placeId,
        ],
      );

      final updatedPlace = Place(
        id: placeId,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        country: json['country'] as String,
        address: json['address'] as String,
        name: json['name'] as String,
      );

      return Response.ok(
        jsonEncode(updatedPlace.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Удаление места
  router.delete('/places/<id>', (Request request, String id) async {
    try {
      final placeId = int.parse(id);
      final conn = await Database.getConnection();

      final result = await conn.execute(
        'DELETE FROM places WHERE id = \$1 RETURNING id',
        parameters: [placeId],
      );

      if (result.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Место не найдено'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'message': 'Место удалено'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Получение изображения по пути
  router.get('/uploads/<path|.*>', (Request request, String imagePath) async {
    try {
      final file = File('uploads/$imagePath');
      if (!await file.exists()) {
        return Response.notFound('Изображение не найдено');
      }
      final bytes = await file.readAsBytes();
      return Response.ok(
        bytes,
        headers: {
          'Content-Type': 'image/jpeg',
          'Content-Length': bytes.length.toString(),
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  return router.call;
}

