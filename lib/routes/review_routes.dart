import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database.dart';
import '../models/review.dart';
import 'dart:convert';

Handler reviewRoutes() {
  final router = Router();

  // Создание отзыва
  router.post('/reviews', (Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final review = Review.fromJson(json);

      // Валидация оценки
      if (review.rating < 1 || review.rating > 5) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Оценка должна быть от 1 до 5'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final conn = await Database.getConnection();
      final result = await conn.execute(
        'INSERT INTO reviews (user_id, place_id, text, rating) VALUES (\$1, \$2, \$3, \$4) RETURNING id',
        parameters: [
          review.userId,
          review.placeId,
          review.text,
          review.rating,
        ],
      );

      final reviewId = result.first[0] as int;
      final createdReview = Review(
        id: reviewId,
        userId: review.userId,
        placeId: review.placeId,
        text: review.text,
        rating: review.rating,
      );

      return Response.ok(
        jsonEncode(createdReview.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Получение всех отзывов
  router.get('/reviews', (Request request) async {
    try {
      final conn = await Database.getConnection();
      final result = await conn.execute('SELECT * FROM reviews');

      final reviews = result.map((row) {
        return Review(
          id: row[0] as int,
          userId: row[1] as int,
          placeId: row[2] as int,
          text: row[3] as String,
          rating: row[4] as int,
        ).toJson();
      }).toList();

      return Response.ok(
        jsonEncode(reviews),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Получение отзыва по ID
  router.get('/reviews/<id>', (Request request, String id) async {
    try {
      final reviewId = int.parse(id);
      final conn = await Database.getConnection();
      final result = await conn.execute(
        'SELECT * FROM reviews WHERE id = \$1',
        parameters: [reviewId],
      );

      if (result.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Отзыв не найден'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final row = result.first;
      final review = Review(
        id: row[0] as int,
        userId: row[1] as int,
        placeId: row[2] as int,
        text: row[3] as String,
        rating: row[4] as int,
      );

      return Response.ok(
        jsonEncode(review.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Обновление отзыва
  router.put('/reviews/<id>', (Request request, String id) async {
    try {
      final reviewId = int.parse(id);
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      // Валидация оценки
      final rating = json['rating'] as int;
      if (rating < 1 || rating > 5) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Оценка должна быть от 1 до 5'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final conn = await Database.getConnection();

      // Проверяем существование отзыва
      final checkResult = await conn.execute(
        'SELECT id FROM reviews WHERE id = \$1',
        parameters: [reviewId],
      );

      if (checkResult.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Отзыв не найден'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final userId = json['userId'] as int? ?? json['user_id'] as int;
      final placeId = json['placeId'] as int? ?? json['place_id'] as int;

      await conn.execute(
        'UPDATE reviews SET user_id = \$1, place_id = \$2, text = \$3, rating = \$4 WHERE id = \$5',
        parameters: [
          userId,
          placeId,
          json['text'] as String,
          rating,
          reviewId,
        ],
      );

      final updatedReview = Review(
        id: reviewId,
        userId: userId,
        placeId: placeId,
        text: json['text'] as String,
        rating: rating,
      );

      return Response.ok(
        jsonEncode(updatedReview.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Удаление отзыва
  router.delete('/reviews/<id>', (Request request, String id) async {
    try {
      final reviewId = int.parse(id);
      final conn = await Database.getConnection();

      final result = await conn.execute(
        'DELETE FROM reviews WHERE id = \$1 RETURNING id',
        parameters: [reviewId],
      );

      if (result.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Отзыв не найден'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'message': 'Отзыв удален'}),
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

