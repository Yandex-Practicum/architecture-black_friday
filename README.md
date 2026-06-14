# MongoDB: шардирование, репликация и кеширование

Итоговая архитектура находится в `architecture.drawio` и содержит пять
последовательных схем. Основной стенд для проверки находится в
`sharding-repl-cache`.

## Запуск основного стенда

```bash
cd sharding-repl-cache
docker compose up -d
./scripts/init.sh
```

Init-скрипт идемпотентен: его можно запускать повторно. Он создаёт два шарда,
по три реплики в каждом, шардирует `somedb.helloDoc` по hashed `_id` и
заполняет коллекцию 1200 документами.

## Проверка

Состояние сервисов:

```bash
docker compose ps
```

JSON приложения:

```bash
curl -s http://localhost:8080/ | jq
```

Ожидаемые поля: `mongo_topology_type` равно `Sharded`, `documents_count` не
меньше `1200`, в `shard_document_counts` присутствуют два шарда,
`shard_replica_counts` равно `3` для каждого шарда, `cache_enabled` равно
`true`.

Распределение документов по шардам:

```bash
docker compose exec -T mongos mongosh --port 27017 --quiet --eval \
  'db.getSiblingDB("somedb").helloDoc.getShardDistribution()'
```

Состояние реплик:

```bash
docker compose exec -T shard1-1 mongosh --port 27017 --quiet --eval \
  'rs.status().members.map(({name,stateStr}) => ({name,stateStr}))'
docker compose exec -T shard2-1 mongosh --port 27017 --quiet --eval \
  'rs.status().members.map(({name,stateStr}) => ({name,stateStr}))'
```

Проверка Redis-кеша:

```bash
./scripts/verify-cache.sh
```

Первый вызов `/helloDoc/users` выполняется с искусственной задержкой около
одной секунды, повторный вызов из кеша должен быть быстрее 100 мс.

## Отдельные этапы

Каждый этап запускается одинаково из соответствующей директории:

```bash
cd mongo-sharding        # или mongo-sharding-repl
docker compose up -d
./scripts/init.sh
```

Перед запуском другого этапа остановите текущий стенд командой
`docker compose down`, поскольку все этапы публикуют приложение на порту
`8080`.
