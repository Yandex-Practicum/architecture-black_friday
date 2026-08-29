# Шардирование MongoDB

![Схема этого этапа](<../task1-1 - Шардирование.drawio.svg>)

Коллекция `somedb.helloDoc` распределяется между двумя шардами по хешированному `_id`. Приложение подключается к `mongos`, а конфигурация кластера хранится в `config-rs`.

В стенд входят:

- `configsvr` — config server на порте `27019`;
- `shard1` и `shard2` — односоставные replica set на порте `27018`;
- `mongos` — маршрутизатор запросов на порте `27017`;
- `pymongo_api` — приложение на порте `8080`.

## Запуск и инициализация

1. Запустите контейнеры из директории `mongo-sharding`:

   ```shell
   docker compose up -d
   ```

2. Запустите настройку кластера:

   ```shell
   ./scripts/mongo-init.sh
   ```

   Скрипт выполняет следующие действия:

   - ждёт готовности всех процессов MongoDB;
   - создаёт `config-rs`, `shard1-rs` и `shard2-rs`;
   - добавляет `shard1-rs` и `shard2-rs` в кластер через `mongos`;
   - включает шардирование базы `somedb` и коллекции `helloDoc`;
   - задаёт shard key `{ _id: "hashed" }`;
   - добавляет 1000 документов и выводит количество записей на каждом шарде.

3. Проверьте состояние контейнеров:

   ```shell
   docker compose ps
   ```

Повторный запуск `mongo-init.sh` безопасен: существующая конфигурация сохраняется, а тестовые записи обновляются по `_id`.

## Проверка результата

```shell
curl --silent http://localhost:8080/ | jq
curl --silent http://localhost:8080/helloDoc/count | jq
```

В первом ответе `mongo_topology_type` должен быть равен `Sharded`, во втором `items_count` должен быть не меньше `1000`.

Список зарегистрированных шардов:

```shell
docker compose exec -T mongos mongosh --port 27017 --quiet --eval 'db.adminCommand({ listShards: 1 })'
```

Количество документов на каждом шарде:

```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments({})'
docker compose exec -T shard2 mongosh --port 27018 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments({})'
```

Оба результата должны быть больше нуля, а их сумма — не меньше 1000.

## Остановка

```shell
docker compose down
```

Удалить контейнеры вместе с данными:

```shell
docker compose down -v
```
