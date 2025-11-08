# MongoDB Sharding Demo

Демонстрационный проект MongoDB шардинга с двумя шардами, config server и mongos роутером. Проект включает FastAPI приложение для работы с зашардированной базой данных.

## 📋 Содержание

- [Архитектура](#архитектура)
- [Компоненты системы](#компоненты-системы)
- [Требования](#требования)
- [Быстрый старт](#быстрый-старт)
- [Подробная инструкция по запуску](#подробная-инструкция-по-запуску)
- [Проверка работы](#проверка-работы)
- [Полезные команды](#полезные-команды)
- [API эндпоинты](#api-эндпоинты)
- [Устранение неполадок](#устранение-неполадок)

## 🏗️ Архитектура

Проект реализует MongoDB шардинг с следующей архитектурой:

```
┌─────────────────┐
│   FastAPI App   │
│   (Port 8080)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Mongos Router │
│   (Port 27020)  │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌────────┐
│ Shard1 │ │ Shard2 │
│ :27018 │ │ :27019 │
└────────┘ └────────┘
    │         │
    └────┬────┘
         │
         ▼
┌─────────────────┐
│  Config Server   │
│   (Port 27017)   │
└─────────────────┘
```

### Принцип работы

1. **Config Server** - хранит метаданные о шардах и распределении данных
2. **Shard1 и Shard2** - хранят данные, распределенные по shard key
3. **Mongos Router** - направляет запросы к нужным шардам на основе shard key
4. **FastAPI App** - приложение, которое подключается к mongos и работает с данными

## 🔧 Компоненты системы

### 1. Config Server (`configSrv`)
- **Порт**: 27017
- **IP**: 173.17.0.10
- **Назначение**: Хранит метаданные о шардах, chunks и распределении данных
- **Replica Set**: `config_server`

### 2. Shard1 (`shard1`)
- **Порт**: 27018
- **IP**: 173.17.0.9
- **Назначение**: Первый шард для хранения данных
- **Replica Set**: `shard1`

### 3. Shard2 (`shard2`)
- **Порт**: 27019
- **IP**: 173.17.0.8
- **Назначение**: Второй шард для хранения данных
- **Replica Set**: `shard2`

### 4. Mongos Router (`mongos`)
- **Порт**: 27020 (внешний) → 27017 (внутренний)
- **IP**: 173.17.0.7
- **Назначение**: Роутер запросов, направляет операции к нужным шардам

### 5. FastAPI Application (`mongo-sharding`)
- **Порт**: 8080
- **Назначение**: REST API для работы с зашардированной базой данных

### Init контейнеры

Автоматически инициализируют replica sets перед запуском mongos:
- `configSrv-init` - инициализирует config server replica set
- `shard1-init` - инициализирует shard1 replica set
- `shard2-init` - инициализирует shard2 replica set

## 📦 Требования

- Docker и Docker Compose
- Доступ к интернету для загрузки образов
- Минимум 4GB свободной RAM

## 🚀 Быстрый старт

```bash
# 1. Запустить все сервисы
docker compose up -d

# 2. Дождаться полной инициализации (30-60 секунд)
# Проверить статус:
docker compose ps

# 3. Инициализировать шардинг и заполнить данными
./scripts/mongo-init.sh

# 4. Проверить работу
curl http://localhost:8080
```

## 📖 Подробная инструкция по запуску

### Шаг 1: Запуск контейнеров

```bash
docker compose up -d
```

Эта команда запустит:
1. Config Server и его init контейнер
2. Shard1 и Shard2 с их init контейнерами
3. Mongos (после успешной инициализации всех replica sets)
4. FastAPI приложение (после готовности mongos)

### Шаг 2: Проверка статуса сервисов

```bash
# Проверить статус всех контейнеров
docker compose ps

# Проверить логи mongos (должен успешно подключиться к config server)
docker compose logs mongos | tail -20

# Проверить логи init контейнеров
docker compose logs configSrv-init
docker compose logs shard1-init
docker compose logs shard2-init
```

### Шаг 3: Инициализация шардинга

```bash
# Запустить скрипт инициализации
./scripts/mongo-init.sh
```

Скрипт выполняет:
1. Инициализацию replica sets (если еще не инициализированы)
2. Добавление шардов в кластер через mongos
3. Включение шардинга для базы данных `somedb`
4. Создание hashed shard key для коллекции `helloDoc`
5. Заполнение базы данных 1000 тестовыми документами

### Шаг 4: Проверка распределения данных

```bash
# Проверить статус шардинга
docker compose exec -T mongos mongosh --eval "sh.status()"

# Проверить распределение данных по шардам
docker compose exec -T mongos mongosh somedb --eval "db.helloDoc.getShardDistribution()"

# Проверить количество документов на каждом шарде
docker compose exec -T shard1 mongosh --port 27018 somedb --eval "db.helloDoc.countDocuments()"
docker compose exec -T shard2 mongosh --port 27019 somedb --eval "db.helloDoc.countDocuments()"
```

## ✅ Проверка работы

### 1. Проверка через веб-интерфейс

Откройте в браузере:
- **Локально**: http://localhost:8080
- **На удаленном сервере**: http://<IP_СЕРВЕРА>:8080

Главная страница покажет:
- Тип топологии MongoDB (должно быть "Sharded")
- Информацию о шардах
- Количество документов в коллекциях
- Статус кэширования (если Redis настроен)

### 2. Проверка через API

```bash
# Получить информацию о базе данных
curl http://localhost:8080

# Получить количество документов в коллекции
curl http://localhost:8080/helloDoc/count

# Получить список пользователей
curl http://localhost:8080/helloDoc/users

# Swagger документация
open http://localhost:8080/docs
```

### 3. Проверка шардинга

```bash
# Проверить, что данные распределены между шардами
docker compose exec -T mongos mongosh somedb --eval "db.helloDoc.getShardDistribution()"
```

Ожидаемый результат:
- Shard1: ~50% документов
- Shard2: ~50% документов

## 🛠️ Полезные команды

### Работа с MongoDB

```bash
# Подключиться к mongos
docker compose exec -T mongos mongosh

# Подключиться к config server
docker compose exec -T configSrv mongosh --port 27017

# Подключиться к shard1
docker compose exec -T shard1 mongosh --port 27018

# Подключиться к shard2
docker compose exec -T shard2 mongosh --port 27019

# Проверить статус replica set
docker compose exec -T configSrv mongosh --port 27017 --eval "rs.status()"
docker compose exec -T shard1 mongosh --port 27018 --eval "rs.status()"
docker compose exec -T shard2 mongosh --port 27019 --eval "rs.status()"
```

### Работа с данными

```bash
# Заполнить базу данных вручную
docker compose exec -T mongos mongosh somedb <<'EOF'
var docs = [];
for(var i = 0; i < 1000; i++) {
  docs.push({age: i, name: "ly" + i});
}
db.helloDoc.insertMany(docs);
EOF

# Проверить количество документов
docker compose exec -T mongos mongosh somedb --eval "db.helloDoc.countDocuments()"

# Найти документ
docker compose exec -T mongos mongosh somedb --eval "db.helloDoc.findOne({age: 100})"
```

### Управление контейнерами

```bash
# Остановить все сервисы
docker compose down

# Остановить и удалить volumes (удалит все данные!)
docker compose down -v

# Перезапустить сервис
docker compose restart mongos

# Просмотр логов
docker compose logs -f mongos
docker compose logs -f mongo-sharding
```

## 📡 API эндпоинты

### Основные эндпоинты

- `GET /` - Информация о базе данных, топологии и шардах
- `GET /{collection_name}/count` - Количество документов в коллекции
- `GET /{collection_name}/users` - Список всех пользователей (с кэшированием)
- `GET /{collection_name}/users/{name}` - Получить пользователя по имени
- `POST /{collection_name}/users` - Создать нового пользователя

### Примеры запросов

```bash
# Создать пользователя
curl -X POST http://localhost:8080/helloDoc/users \
  -H "Content-Type: application/json" \
  -d '{"age": 25, "name": "John Doe"}'

# Получить пользователя
curl http://localhost:8080/helloDoc/users/John%20Doe

# Получить всех пользователей
curl http://localhost:8080/helloDoc/users
```

### Swagger документация

Полная интерактивная документация доступна по адресу:
- http://localhost:8080/docs

## 🔍 Устранение неполадок

### Проблема: Mongos не запускается

**Симптомы**: Контейнер mongos постоянно перезапускается или показывает ошибки подключения к config server.

**Решение**:
```bash
# Проверить, что config server инициализирован
docker compose exec -T configSrv mongosh --port 27017 --eval "rs.status()"

# Если не инициализирован, запустить init контейнер вручную
docker compose up configSrv-init

# Проверить логи
docker compose logs mongos
docker compose logs configSrv-init
```

### Проблема: Данные не распределяются между шардами

**Симптомы**: Все данные находятся только на одном шарде.

**Решение**:
```bash
# Проверить shard key
docker compose exec -T mongos mongosh --eval "sh.status()" | grep -A 10 "helloDoc"

# Если используется range shard key, пересоздать с hashed:
docker compose exec -T mongos mongosh somedb <<'EOF'
db.helloDoc.drop()
sh.shardCollection("somedb.helloDoc", { age: "hashed" })
EOF
```

### Проблема: Init контейнеры не завершаются

**Симптомы**: Init контейнеры зависают или завершаются с ошибкой.

**Решение**:
```bash
# Проверить логи init контейнеров
docker compose logs configSrv-init
docker compose logs shard1-init
docker compose logs shard2-init

# Проверить, что основные сервисы запущены
docker compose ps

# Перезапустить init контейнеры
docker compose up configSrv-init shard1-init shard2-init
```

### Проблема: Приложение не подключается к MongoDB

**Симптомы**: Ошибки подключения в логах приложения.

**Решение**:
```bash
# Проверить, что mongos доступен
docker compose exec -T mongos mongosh --eval "db.adminCommand('ping')"

# Проверить переменные окружения приложения
docker compose exec mongo-sharding env | grep MONGODB

# Проверить логи приложения
docker compose logs mongo-sharding
```

### Проблема: Порты заняты

**Симптомы**: Ошибка при запуске "port is already allocated".

**Решение**:
```bash
# Найти процесс, использующий порт
lsof -i :27017
lsof -i :27018
lsof -i :27019
lsof -i :27020
lsof -i :8080

# Остановить конфликтующие контейнеры
docker compose down

# Или изменить порты в compose.yaml
```

## 📊 Мониторинг и метрики

### Проверка распределения данных

```bash
# Детальная информация о распределении
docker compose exec -T mongos mongosh somedb --eval "db.helloDoc.getShardDistribution()"

# Статус шардинга
docker compose exec -T mongos mongosh --eval "sh.status()"

# Информация о chunks
docker compose exec -T mongos mongosh --eval "sh.status()" | grep -A 20 "chunks"
```

### Проверка производительности

```bash
# Статистика по коллекции
docker compose exec -T mongos mongosh somedb --eval "db.helloDoc.stats()"

# Информация о индексах
docker compose exec -T mongos mongosh somedb --eval "db.helloDoc.getIndexes()"
```

## 🔐 Безопасность

⚠️ **Важно**: Данная конфигурация предназначена для разработки и тестирования. В production окружении необходимо:

1. Включить аутентификацию MongoDB
2. Настроить SSL/TLS шифрование
3. Использовать сетевые политики
4. Ограничить доступ к портам
5. Настроить резервное копирование

## 📝 Структура проекта

```
mongo-sharding/
├── api_app/              # FastAPI приложение
│   ├── app.py           # Основной код приложения
│   ├── Dockerfile       # Docker образ приложения
│   └── requirements.txt # Python зависимости
├── scripts/
│   └── mongo-init.sh    # Скрипт инициализации шардинга
├── compose.yaml         # Docker Compose конфигурация
└── README.md           # Документация
```

## 🎯 Особенности реализации

### Hashed Shard Key

Проект использует **hashed shard key** (`{ age: "hashed" }`) для равномерного распределения данных между шардами. Это обеспечивает:

- Равномерное распределение данных (~50/50)
- Хорошую производительность при вставках
- Автоматическое распределение нагрузки

### Автоматическая инициализация

Init контейнеры автоматически:
- Инициализируют replica sets
- Ждут готовности сервисов
- Проверяют статус PRIMARY перед завершением

### Health Checks

Все сервисы имеют health checks для:
- Автоматического перезапуска при сбоях
- Правильной последовательности запуска
- Мониторинга состояния

## 📚 Дополнительные ресурсы

- [MongoDB Sharding Documentation](https://docs.mongodb.com/manual/sharding/)
- [MongoDB Shard Keys](https://docs.mongodb.com/manual/core/sharding-shard-key/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

## 🤝 Поддержка

При возникновении проблем:
1. Проверьте логи: `docker compose logs`
2. Проверьте статус контейнеров: `docker compose ps`
3. Убедитесь, что все порты свободны
4. Проверьте, что достаточно ресурсов (RAM, диск)

---

**Версия**: 1.0  
**Последнее обновление**: 2025
