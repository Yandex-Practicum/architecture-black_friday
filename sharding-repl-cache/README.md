# MongoDB sharding, replication and caching

Проект запускает `pymongo-api`, один `mongos`, один config server и два шарда.
Каждый шард состоит из трёх узлов MongoDB. Redis кеширует ответы эндпоинта
`/helloDoc/users`.

## Запуск и инициализация

```sh
docker compose up -d
./scripts/mongo-init.sh
```

Скрипт создаёт replica set `shard1` и `shard2` по три узла в каждом,
подключает их к шардированному кластеру, включает шардирование
`somedb.helloDoc` по хешированному ключу `name` и создаёт 1000 документов.

## Проверка

```sh
docker compose ps
curl --silent http://localhost:8080
curl --silent http://localhost:8080/helloDoc/count
```

В ответе корневого эндпоинта должно быть указано:

```json
"cache_enabled": true
```

Первый запрос получает данные из MongoDB и сохраняет ответ в Redis:

```sh
curl --silent \
  --output /dev/null \
  --write-out '%{time_total}\n' \
  http://localhost:8080/helloDoc/users
```

Повторите ту же команду. Второй и последующие запросы должны выполняться
быстрее `0.1` секунды.

Количество документов на первом шарде:

```sh
docker compose exec -T mongos_router mongosh \
  'mongodb://shard1-1:27018,shard1-2:27018,shard1-3:27018/somedb?replicaSet=shard1' \
  --quiet \
  --eval 'db.helloDoc.countDocuments()'
```

Количество документов на втором шарде:

```sh
docker compose exec -T mongos_router mongosh \
  'mongodb://shard2-1:27019,shard2-2:27019,shard2-3:27019/somedb?replicaSet=shard2' \
  --quiet \
  --eval 'db.helloDoc.countDocuments()'
```

Состояние узлов первого replica set:

```sh
docker compose exec -T shard1-1 mongosh \
  --port 27018 \
  --quiet \
  --eval 'rs.status().members.map(({name, stateStr}) => ({name, stateStr}))'
```

Состояние узлов второго replica set:

```sh
docker compose exec -T shard2-1 mongosh \
  --port 27019 \
  --quiet \
  --eval 'rs.status().members.map(({name, stateStr}) => ({name, stateStr}))'
```

## Остановка

```sh
docker compose down
```

Чтобы полностью удалить данные и повторить инициализацию:

```sh
docker compose down -v
```
