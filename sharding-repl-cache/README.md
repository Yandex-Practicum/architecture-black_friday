# MongoDB с шардированием, репликацией и кешированием

Полная production-ready настройка с шардированием, репликацией и Redis кешированием.

## Быстрый старт

```bash
docker compose up -d
./scripts/init-sharding-repl.sh
```

> **Примечание:** Compose файл использует локальную сборку для совместимости. Для x86/AMD64 можно использовать готовый образ, раскомментировав строку `image` в compose.yaml.

Проверка:

```bash
curl http://localhost:8080
```

## Что внутри

- 3 Config Server (replica set)
- 6 Shard Server (2 шарда × 3 реплики)
- 1 роутер Mongos
- 1 Redis кеш
- 1 API приложение

Всего: 12 контейнеров

## Тест производительности кеша

Первый запрос (медленный ~1с):

```bash
time curl -s http://localhost:8080/helloDoc/users > /dev/null
```

Повторный запрос (быстрый <100мс):

```bash
time curl -s http://localhost:8080/helloDoc/users > /dev/null
```

Ключи в Redis:

```bash
docker compose exec redis redis-cli KEYS "*"
```

## Проверка настройки

Статус шардирования:

```bash
docker compose exec mongos mongosh --quiet --eval "sh.status()"
```

Статус репликации:

```bash
docker compose exec shard1-1 mongosh --port 27018 --quiet --eval "rs.status()"
```

Количество документов:

```bash
# Общее
curl -s http://localhost:8080 | jq '.collections.helloDoc.documents_count'

# По шардам
docker compose exec shard1-1 mongosh --port 27018 --quiet --eval "use somedb; db.helloDoc.countDocuments()"
docker compose exec shard2-1 mongosh --port 27019 --quiet --eval "use somedb; db.helloDoc.countDocuments()"
```

Статус кеша:

```bash
curl -s http://localhost:8080 | jq '.cache_enabled'  # должно быть true
```

## Очистка

```bash
docker compose down -v
```

## Порты

- 8080 - API
- 27017 - MongoDB (mongos)
- 6379 - Redis
