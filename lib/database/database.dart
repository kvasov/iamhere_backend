import 'dart:io';
import 'package:postgres/postgres.dart';

class Database {
  static Connection? _connection;

  static Future<Connection> getConnection() async {
    if (_connection != null) {
      return _connection!;
    }

    final host = Platform.environment['DB_HOST'] ?? 'localhost';
    final port = int.tryParse(Platform.environment['DB_PORT'] ?? '5432') ?? 5432;
    final database = Platform.environment['DB_NAME'] ?? 'iamhere';
    final username = Platform.environment['DB_USER'] ?? 'dmitry';
    final password = Platform.environment['DB_PASSWORD'] ?? '';

    _connection = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: const ConnectionSettings(
        sslMode: SslMode.disable, // важно для localhost
      ),
    );

    await _initTables();
    return _connection!;
  }

  static Future<void> _initTables() async {
    final conn = _connection;
    if (conn == null) return;

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) NOT NULL UNIQUE,
        login VARCHAR(255) NOT NULL UNIQUE,
        password VARCHAR(255) NOT NULL
      )
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS places (
        id SERIAL PRIMARY KEY,
        latitude DOUBLE PRECISION NOT NULL,
        longitude DOUBLE PRECISION NOT NULL,
        country VARCHAR(255) NOT NULL,
        address VARCHAR(500) NOT NULL,
        name VARCHAR(255) NOT NULL
      )
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS reviews (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        place_id INTEGER NOT NULL REFERENCES places(id) ON DELETE CASCADE,
        text TEXT NOT NULL,
        rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5)
      )
    ''');

    await conn.execute(
      'CREATE INDEX IF NOT EXISTS idx_reviews_user_id ON reviews(user_id)',
    );
    await conn.execute(
      'CREATE INDEX IF NOT EXISTS idx_reviews_place_id ON reviews(place_id)',
    );

    // Создание таблицы фотографий
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS photos (
        id SERIAL PRIMARY KEY,
        path VARCHAR(500) NOT NULL UNIQUE
      )
    ''');

    // Создание таблицы связи мест и фотографий
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS photo_places (
        place_id INTEGER NOT NULL REFERENCES places(id) ON DELETE CASCADE,
        image_id INTEGER NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
        PRIMARY KEY (place_id, image_id)
      )
    ''');

    // Создание индексов для фотографий
    await conn.execute(
      'CREATE INDEX IF NOT EXISTS idx_photo_places_place_id ON photo_places(place_id)',
    );
    await conn.execute(
      'CREATE INDEX IF NOT EXISTS idx_photo_places_image_id ON photo_places(image_id)',
    );

    // Создание таблицы токенов для авторизации
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS tokens (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token VARCHAR(255) NOT NULL UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMP NOT NULL
      )
    ''');

    await conn.execute(
      'CREATE INDEX IF NOT EXISTS idx_tokens_user_id ON tokens(user_id)',
    );
    await conn.execute(
      'CREATE INDEX IF NOT EXISTS idx_tokens_token ON tokens(token)',
    );
  }

  static Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }
}
