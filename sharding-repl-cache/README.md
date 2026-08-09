# MongoDB sharding, replication and Redis cache

Проект содержит `pymongo-api`, `mongos`, config server, два шарда по три реплики и один Redis-инстанс. Redis кеширует ответы endpoint `/<collection_name>/users` на 60 секунд.

## Запуск и настройка

Остановите другой проект, если он уже занимает порт `8080`. Затем из директории `sharding-repl-cache` выполните:

```sh
docker compose up -d --build
chmod +x init-sharding.sh
./init-sharding.sh
```

Скрипт создаёт replica set для каждого шарда, ждёт по три healthy-реплики, регистрирует шарды, настраивает `somedb.helloDoc`, создаёт 1000 документов и очищает Redis. Все ожидания ограничены 120 секундами; повторный запуск безопасен.

Скрипт автоматически выбирает доступную команду `docker compose` или `docker-compose`.

## Проверка кластера

```sh
curl --fail http://localhost:8080/
curl --fail http://localhost:8080/helloDoc/count
```

Корневой endpoint должен вернуть:

- `mongo_topology_type: Sharded`;
- `collections.helloDoc.documents_count` не меньше 1000;
- количество документов в `shard1-rs` и `shard2-rs`;
- `replicas_count: 3` для каждого шарда;
- `cache_enabled: true`.

## Проверка скорости кеша

Очистите кеш и выполните два одинаковых запроса:

```sh
docker compose exec -T redis redis-cli FLUSHDB

curl --output /dev/null --silent --write-out 'first:  %{time_total}s\n' \
  http://localhost:8080/helloDoc/users

curl --output /dev/null --silent --write-out 'second: %{time_total}s\n' \
  http://localhost:8080/helloDoc/users
```

Первый запрос выполняется около одной секунды и записывает ответ в Redis. Второй и последующие запросы до истечения TTL должны выполняться быстрее `0.100` секунды.

Проверка наличия ключа и его TTL:

```sh
docker compose exec -T redis redis-cli DBSIZE
docker compose exec -T redis redis-cli --scan
```

## Остановка

```sh
docker compose down
```

Данные сохраняются в Docker volumes. Команда `docker compose down -v` удаляет их полностью.
