# MongoDB sharding

Стенд содержит один `mongos`, однокомпонентный replica set конфигурационного сервера и два шарда. Каждый шард на этом этапе представлен однокомпонентным replica set, потому что современные версии MongoDB подключают шарды к кластеру именно как replica set.

## Запуск

```bash
docker compose up -d
./scripts/init.sh
```

Скрипт можно запускать повторно: он проверяет существующую конфигурацию и добавляет только недостающие данные.

## Проверка

```bash
docker compose ps
curl http://localhost:8080/

docker compose exec -T mongos-router mongosh --port 27020 --quiet \
  --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'

docker compose exec -T shard1 mongosh --port 27018 --quiet \
  --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'

docker compose exec -T shard2 mongosh --port 27019 --quiet \
  --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'
```

Корневой эндпоинт приложения должен показать `mongo_topology_type: Sharded`, два шарда и не менее 1000 документов в коллекции `helloDoc`. На каждом шарде должно находиться ненулевое количество документов.

## Остановка

```bash
docker compose down
```

Для полного сброса вместе с данными:

```bash
docker compose down -v
```
