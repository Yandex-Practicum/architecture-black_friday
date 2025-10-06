# MongoDB с шардированием и репликацией

MongoDB кластер с шардированием и репликацией для высокой доступности.

## Запуск

```bash
docker compose up -d
./scripts/init-sharding-repl.sh
```

> **Примечание:** Compose файл использует локальную сборку для совместимости. Для x86/AMD64 можно использовать готовый образ, раскомментировав строку `image` в compose.yaml.

Проверка:

```bash
curl http://localhost:8080
```

## Архитектура

- Config Server: 3 реплики
- Shard 1: 3 реплики
- Shard 2: 3 реплики
- Роутер Mongos
- Всего: 10 нод MongoDB

## Проверка

Статус replica set:

```bash
docker compose exec shard1-1 mongosh --port 27018 --quiet --eval "rs.status()"
```

Распределение документов:

```bash
docker compose exec shard1-1 mongosh --port 27018 --quiet --eval "use somedb; db.helloDoc.countDocuments()"
docker compose exec shard2-1 mongosh --port 27019 --quiet --eval "use somedb; db.helloDoc.countDocuments()"
```

## Тест отказоустойчивости

Остановить реплику:

```bash
docker compose stop shard1-2
curl http://localhost:8080  # должно работать
docker compose start shard1-2
```

## Остановка

```bash
docker compose down -v
```
