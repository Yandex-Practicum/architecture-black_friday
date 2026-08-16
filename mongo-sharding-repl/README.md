# MongoDB sharding with replication

Стенд содержит один `mongos`, однокомпонентный replica set конфигурационного сервера и два шарда. Каждый шард является replica set из трёх узлов: одного `PRIMARY` и двух `SECONDARY`.

## Запуск

```bash
docker compose up -d
./scripts/init.sh
```

Скрипт идемпотентен: повторный запуск не пересоздаёт replica set, шарды и коллекцию, а добавляет только недостающие документы.

## Проверка

```bash
docker compose ps
curl http://localhost:8080/

docker compose exec -T shard1-1 mongosh --port 27018 --quiet \
  --eval 'rs.status().members.map(({name, stateStr}) => ({name, stateStr}))'

docker compose exec -T shard2-1 mongosh --port 27019 --quiet \
  --eval 'rs.status().members.map(({name, stateStr}) => ({name, stateStr}))'

docker compose exec -T mongos-router mongosh --port 27020 --quiet \
  --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'

docker compose exec -T shard1-1 mongosh --port 27018 --quiet \
  --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'

docker compose exec -T shard2-1 mongosh --port 27019 --quiet \
  --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'
```

Корневой эндпоинт приложения должен показать топологию `Sharded`, два шарда, по три адреса узлов в каждом шарде и не менее 1000 документов в коллекции `helloDoc`. В каждом replica set должен быть один `PRIMARY` и два `SECONDARY`.

## Остановка

```bash
docker compose down
```

Для полного сброса вместе с данными:

```bash
docker compose down -v
```
