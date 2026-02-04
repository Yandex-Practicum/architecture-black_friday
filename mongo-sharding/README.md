# pymongo-api

## Как запустить

Запускаем mongodb и приложение

```shell
docker compose up -d
```

Заполняем mongodb данными и инициализируем роутер и конфиг

```shell
./scripts/mongo-init.sh
```

## Как проверить через pymongo-api:

Откройте в браузере http://localhost:8080 - данные о MongoDB

Откройте в браузере http://localhost:8080/helloDoc/count - колличество записей в базе

## Проверка внутри контейнеров средствами mongosh:

docker compose exec -T shard1 mongosh --port 27018 --quiet
shard1 [direct: primary] somed> use somedb
switched to db somedb
shard1 [direct: primary] somedb> db.helloDoc.countDocuments()
492

docker compose exec -T shard2 mongosh --port 27019 --quiet
shard2 [direct: primary] test> use somedb
switched to db somedb
shard2 [direct: primary] somedb> db.helloDoc.countDocuments()
508


docker exec -it mongos_router mongosh somedb --eval "db.helloDoc.getShardDistribution()"


Shard shard1 at shard1/shard1:27018
{
  data: '22KiB',
  docs: 492,
  chunks: 1,
  'estimated data per chunk': '22KiB',
  'estimated docs per chunk': 492
}
---
Shard shard2 at shard2/shard2:27019
{
  data: '23KiB',
  docs: 508,
  chunks: 1,
  'estimated data per chunk': '23KiB',
  'estimated docs per chunk': 508
}
---
Totals
{
  data: '45KiB',
  docs: 1000,
  chunks: 2,
  'Shard shard1': [
    '49.17 % data',
    '49.2 % docs in cluster',
    '46B avg obj size on shard'
  ],
  'Shard shard2': [
    '50.82 % data',
    '50.8 % docs in cluster',
    '46B avg obj size on shard'
  ]
}

