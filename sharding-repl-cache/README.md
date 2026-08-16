# MongoDB sharding with replication and Redis

Стенд содержит `mongos`, конфигурационный сервер, два replica set по три узла и Redis. Приложение получает адрес Redis через переменную `REDIS_URL` и кэширует результат эндпоинта `/{collection_name}/users` на 60 секунд.

## Запуск

```bash
docker compose up -d
./scripts/init.sh
```

Скрипт идемпотентен: повторный запуск не пересоздаёт replica set, шарды и коллекцию, а добавляет только недостающие документы.

## Проверка MongoDB

```bash
docker compose ps
curl http://localhost:8080/

docker compose exec -T shard1-1 mongosh --port 27018 --quiet \
  --eval 'rs.status().members.map(({name, stateStr}) => ({name, stateStr}))'

docker compose exec -T shard2-1 mongosh --port 27019 --quiet \
  --eval 'rs.status().members.map(({name, stateStr}) => ({name, stateStr}))'

docker compose exec -T mongos-router mongosh --port 27020 --quiet \
  --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'
```

Корневой эндпоинт должен показать `mongo_topology_type: Sharded`, `cache_enabled: true`, два шарда по три узла и не менее 1000 документов в коллекции `helloDoc`.

## Проверка кэша

Сначала очистите Redis, затем выполните два одинаковых запроса:

```bash
docker compose exec -T redis redis-cli FLUSHALL

curl -o /dev/null -s -w 'first:  %{time_total}s\n' \
  http://localhost:8080/helloDoc/users

curl -o /dev/null -s -w 'second: %{time_total}s\n' \
  http://localhost:8080/helloDoc/users
```

Первый запрос занимает около секунды из-за искусственной задержки приложения. Второй получает тот же ответ из Redis и должен выполняться менее чем за `0.1` секунды.

## Остановка

```bash
docker compose down
```

Для полного сброса вместе с данными и кэшем:

```bash
docker compose down -v
```
