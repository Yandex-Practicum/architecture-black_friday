# Шардирование, репликация и Redis

![Схема этого этапа](<../task1-3 - Кеширование.drawio.svg>)

Финальный исполняемый стенд состоит из двух шардов MongoDB по три узла, `mongos`, config server, Redis и приложения `pymongo-api`. Ответ `GET /helloDoc/users` сохраняется в Redis на 60 секунд.

## Запуск и инициализация

1. Запустите все сервисы из директории `sharding-repl-cache`:

   ```shell
   docker compose up -d
   ```

2. Выполните инициализацию:

   ```shell
   ./scripts/mongo-init.sh
   ```

   Скрипт последовательно:

   - создаёт односоставной `config-rs`;
   - настраивает `shard1-rs` и `shard2-rs`, по три узла в каждом;
   - ждёт выборов primary и готовности secondary;
   - добавляет оба replica set в `mongos` как шарды;
   - включает шардирование `somedb.helloDoc` по `{ _id: "hashed" }`;
   - создаёт или обновляет 1000 документов;
   - очищает Redis перед замером кеша.

3. Проверьте состояние контейнеров:

   ```shell
   docker compose ps
   ```

Скрипт можно запускать повторно без удаления volumes.

## Проверка MongoDB

```shell
curl --silent http://localhost:8080/ | jq
curl --silent http://localhost:8080/helloDoc/count | jq
```

В ответе `/` проверьте:

- `mongo_topology_type` — `Sharded`;
- `mongo_is_mongos` — `true`;
- `cache_enabled` — `true`;
- `collections.helloDoc.documents_count` — не меньше `1000`;
- в `shards` присутствуют `shard1` и `shard2`, по три адреса в каждом.

Состояние реплик:

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval 'rs.status().members.forEach(member => print(member.name + ": " + member.stateStr))'
docker compose exec -T shard2-1 mongosh --port 27018 --quiet --eval 'rs.status().members.forEach(member => print(member.name + ": " + member.stateStr))'
```

## Проверка кеша

Очистите Redis и дважды запросите один endpoint:

```shell
docker compose exec -T redis redis-cli FLUSHDB
curl --silent --output /dev/null --write-out 'Первый запрос: %{time_total} с\n' http://localhost:8080/helloDoc/users
curl --silent --output /dev/null --write-out 'Повторный запрос: %{time_total} с\n' http://localhost:8080/helloDoc/users
```

Первый запрос занимает около секунды. Второй должен вернуться из Redis быстрее 100 мс. Убедиться, что ключ появился, можно командой:

```shell
docker compose exec -T redis redis-cli KEYS 'api:cache:*'
```

## Остановка

```shell
docker compose down
```

Удалить стенд вместе с данными MongoDB и Redis:

```shell
docker compose down -v
```
