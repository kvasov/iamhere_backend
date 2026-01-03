import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database.dart';
import '../models/place.dart';
import 'dart:convert';

Handler placeRoutes() {
  final router = Router();

  // Создание места
  router.post('/places', (Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final place = Place.fromJson(json);

      final conn = await Database.getConnection();
      final result = await conn.execute(
        'INSERT INTO places (latitude, longitude, country, address, name) VALUES (\$1, \$2, \$3, \$4, \$5) RETURNING id',
        parameters: [
          place.latitude,
          place.longitude,
          place.country,
          place.address,
          place.name,
        ],
      );

      final placeId = result.first[0] as int;
      final createdPlace = Place(
        id: placeId,
        latitude: place.latitude,
        longitude: place.longitude,
        country: place.country,
        address: place.address,
        name: place.name,
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

  // Получение всех мест
  router.get('/places', (Request request) async {
    try {
      final conn = await Database.getConnection();
      final result = await conn.execute('SELECT * FROM places');

      final places = result.map((row) {
        return Place(
          id: row[0] as int,
          latitude: (row[1] as num).toDouble(),
          longitude: (row[2] as num).toDouble(),
          country: row[3] as String,
          address: row[4] as String,
          name: row[5] as String,
        ).toJson();
      }).toList();

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
      final place = Place(
        id: row[0] as int,
        latitude: (row[1] as num).toDouble(),
        longitude: (row[2] as num).toDouble(),
        country: row[3] as String,
        address: row[4] as String,
        name: row[5] as String,
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

  return router.call;
}

