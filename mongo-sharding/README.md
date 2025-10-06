# MongoDB с шардированием

Базовая настройка MongoDB с 2 шардами.

## Запуск

Запустить сервисы:

```bash
docker compose up -d
```

> **Примечание:** Compose файл использует локальную сборку для совместимости. Для x86/AMD64 можно использовать готовый образ, раскомментировав строку `image` в compose.yaml.

Дождаться запуска контейнеров (~10 сек), затем инициализировать:

```bash
./scripts/init-sharding.sh
```

Проверить:

```bash
curl http://localhost:8080
```

## Архитектура

- 1 Config Server
- 2 шарда (shard1, shard2)
- 1 роутер Mongos
- API на порту 8080

База данных: `somedb`, коллекция: `helloDoc`

## Проверка шардирования

Статус кластера:

```bash
docker compose exec mongos mongosh --quiet --eval "sh.status()"
```

Количество документов в каждом шарде:

```bash
docker compose exec shard1 mongosh --port 27018 --quiet --eval "use somedb; db.helloDoc.countDocuments()"
docker compose exec shard2 mongosh --port 27019 --quiet --eval "use somedb; db.helloDoc.countDocuments()"
```

## Остановка

```bash
docker compose down
# или с удалением данных
docker compose down -v
```
