# MongoDB Sharding + Replication + Redis Cache

Репликация и шардинг MongoDB с дополнительным Redis-кешированием для ускорения повторных запросов FastAPI-приложения.

## 📋 Содержание

- [Требования](#требования)
- [Архитектура](#архитектура)
- [Компоненты](#компоненты)
- [Быстрый старт](#быстрый-старт)
- [Детальная инструкция](#детальная-инструкция)
- [Проверка результатов](#проверка-результатов)
- [Полезные команды](#полезные-команды)
- [Устранение неполадок](#устранение-неполадок)

## Требования

- Docker и Docker Compose v2+
- Не менее 6 GB RAM для одновременного запуска MongoDB и Redis
- Свободные порты: `8080`, `27017-27020`, `6379`

## Архитектура

```
┌─────────────────┐        ┌──────────────┐
│   FastAPI App   │───────▶│   Redis 7    │
│   (Port 8080)   │        │   Cache 6379 │
└────────┬────────┘        └──────┬───────┘
         │                        │
         ▼                        │
┌─────────────────┐               │
│   Mongos Router │◀──────────────┘
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

## Компоненты

- `configSrv` — config server (`config_server` replica set)
- `shard1`, `shard2` — шардовые replica sets (`shard1`, `shard2`)
- `mongos` — query router
- `redis` — кеш для эндпоинта `/{collection}/users`
- `mongo-sharding` — FastAPI приложение
- Init-контейнеры — автоматизируют запуск replica set'ов до старта `mongos`

## Быстрый старт

```bash
docker compose up -d
./scripts/mongo-init.sh

# Проверка базы и кеша
curl http://localhost:8080
curl http://localhost:8080/helloDoc/users
curl http://localhost:8080/helloDoc/users  # повтор <100мс
```

## Детальная инструкция

### 1. Запуск инфраструктуры

```bash
docker compose up -d
docker compose ps
```

Будут запущены config server, два шарда c репликацией, mongos, Redis и FastAPI-приложение. Init-контейнеры завершаются автоматически после инициализации replica sets.

### 2. Инициализация шардинга и коллекции

```bash
./scripts/mongo-init.sh
```

Скрипт:

1. Проверяет статус replica set'ов и инициирует их при необходимости
2. Регистрирует шарды через `mongos`
3. Включает шардинг для БД `somedb`
4. Создаёт коллекцию `helloDoc` с hashed shard key `{ age: "hashed" }`
5. Заполняет коллекцию ≥1000 тестовыми документами

### 3. Предварительная проверка

```bash
docker compose exec -T mongos mongosh --quiet --eval "sh.status()"
docker compose exec -T mongos mongosh somedb --quiet --eval "db.helloDoc.countDocuments()"
docker compose exec -T redis redis-cli ping
```

## Проверка результатов

### 1. API

```bash
# Общая информация и статус кеша
curl http://localhost:8080

# Количество документов
curl http://localhost:8080/helloDoc/count
```

### 2. Распределение по шардам и репликам

```bash
docker compose exec -T mongos mongosh somedb --quiet --eval "db.helloDoc.getShardDistribution()"
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "rs.status().members.map(m => m.stateStr)"
docker compose exec -T shard2 mongosh --port 27019 --quiet --eval "rs.status().members.map(m => m.stateStr)"
```

### 3. Проверка кеширования (<100 мс)

```bash
# Первый запрос — чтение из MongoDB (~1 сек из-за time.sleep)
time curl -s http://localhost:8080/helloDoc/users > /tmp/users.json

# Повтор — чтение из Redis, должно занять <100 мс
time curl -s http://localhost:8080/helloDoc/users > /tmp/users_cached.json

diff /tmp/users.json /tmp/users_cached.json >/dev/null && echo "Cache hit OK"
```

## Полезные команды

```bash
# Подключение к mongos
docker compose exec -T mongos mongosh

# Статус replica sets
docker compose exec -T shard1 mongosh --port 27018 --eval "rs.status()"
docker compose exec -T shard2 mongosh --port 27019 --eval "rs.status()"

# Мониторинг Redis
docker compose exec -T redis redis-cli info stats | head

# Логи
docker compose logs -f mongo-sharding
docker compose logs -f mongos
docker compose logs -f redis
```

## Устранение неполадок

- `mongos` не стартует — проверьте `docker compose logs configSrv-init` и убедитесь, что replica set `config_server` в состоянии `PRIMARY`.
- Данные не распределяются — убедитесь, что `sh.enableSharding("somedb")` и `sh.shardCollection("somedb.helloDoc", { age: "hashed" })` выполнены (повторите `./scripts/mongo-init.sh`).
- `cache_enabled: false` — проверьте переменную окружения `REDIS_URL` и состояние Redis (`docker compose exec -T redis redis-cli ping`).
- Время ответа >100 мс — убедитесь, что второй запрос отправляется сразу после первого; при необходимости очистите кеш `docker compose exec -T redis redis-cli FLUSHALL`.

---

Проект предназначен для учебных целей. Для продуктивной среды добавьте авторизацию MongoDB, резервное копирование и мониторинг.
