# IAM Here Backend

Backend API на Dart с использованием фреймворка Shelf и PostgreSQL.

## Требования

- Dart SDK >= 3.0.0
- PostgreSQL

## Установка

1. Установите зависимости:
```bash
dart pub get
```

2. Настройте переменные окружения (опционально):
```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=iamhere
export DB_USER=postgres
export DB_PASSWORD=postgres
export PORT=8080
```

Или создайте файл `.env` (требуется пакет dotenv).

3. Создайте базу данных PostgreSQL:
```sql
CREATE DATABASE iamhere;
```

## Запуск

```bash
dart run lib/main.dart
```

Сервер запустится на `http://localhost:8080`

## API Endpoints

### Пользователи

- `POST /api/users` - создание пользователя
- `GET /api/users` - получение всех пользователей
- `GET /api/users/<id>` - получение пользователя по ID
- `PUT /api/users/<id>` - обновление пользователя
- `DELETE /api/users/<id>` - удаление пользователя

**Пример создания пользователя:**
```json
{
  "name": "Иван Иванов",
  "email": "ivan@example.com",
  "login": "ivan",
  "password": "password123"
}
```

### Места

- `POST /api/places` - создание места
- `GET /api/places` - получение всех мест
- `GET /api/places/<id>` - получение места по ID
- `PUT /api/places/<id>` - обновление места
- `DELETE /api/places/<id>` - удаление места

**Пример создания места:**
```json
{
  "latitude": 55.7558,
  "longitude": 37.6173,
  "country": "Россия",
  "address": "Красная площадь, 1",
  "name": "Красная площадь"
}
```

### Отзывы

- `POST /api/reviews` - создание отзыва
- `GET /api/reviews` - получение всех отзывов
- `GET /api/reviews/<id>` - получение отзыва по ID
- `PUT /api/reviews/<id>` - обновление отзыва
- `DELETE /api/reviews/<id>` - удаление отзыва

**Пример создания отзыва:**
```json
{
  "userId": 1,
  "placeId": 1,
  "text": "Отличное место!",
  "rating": 5
}
```

## Структура базы данных

### Таблица users
- `id` (SERIAL PRIMARY KEY)
- `name` (VARCHAR(255))
- `email` (VARCHAR(255) UNIQUE)
- `login` (VARCHAR(255) UNIQUE)
- `password` (VARCHAR(255))

### Таблица places
- `id` (SERIAL PRIMARY KEY)
- `latitude` (DOUBLE PRECISION)
- `longitude` (DOUBLE PRECISION)
- `country` (VARCHAR(255))
- `address` (VARCHAR(500))
- `name` (VARCHAR(255))

### Таблица reviews
- `id` (SERIAL PRIMARY KEY)
- `user_id` (INTEGER, FOREIGN KEY -> users.id)
- `place_id` (INTEGER, FOREIGN KEY -> places.id)
- `text` (TEXT)
- `rating` (INTEGER, CHECK 1-5)

Таблицы создаются автоматически при первом запуске приложения.

