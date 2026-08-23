# Задание 2. Шардирование MongoDB

## Как запустить

Запускаем mongo-sharding и приложение

Перейти в папку mongo-sharding

Выполните:
```shell
docker compose up -d
```

После выполнения docker compose up -d подождите 15-20 секунд, чтобы все контейнеры MongoDB полностью стартовали, и после этого запустите скрипт инициализации из следующего шага. Если скрипт запустить раньше, инициализация конфиг сервера может не пройти.

Инициализация шардирования и наполнение данными

В папке mongo-sharding выполните:
```shell
./scripts/init.sh
```

## Как проверить

### Если вы запускаете проект на локальной машине

Откройте в браузере http://localhost:8080

Пример вывода:
```
{"mongo_topology_type":"Sharded","mongo_replicaset_name":null,"mongo_db":"somedb","read_preference":"Primary()","mongo_nodes":[["mongos_router",27020]],"mongo_primary_host":null,"mongo_secondary_hosts":[],"mongo_is_primary":true,"mongo_is_mongos":true,"collections":{"helloDoc":{"documents_count":1000}},"shards":{"shard1":"shard1/shard1:27018","shard2":"shard2/shard2:27019"},"cache_enabled":false,"status":"OK"}
```

### Перейдя в папку mongo-sharding можно проверить распределение документов по шардам

Выполните инструкцию
```shell
docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval "db.getSiblingDB('somedb').helloDoc.getShardDistribution()"
```

Пример вывода:
```
Shard shard2 at shard2/shard2:27019
{
  data: '22KiB',
  docs: 491,
  chunks: 1,
  'estimated data per chunk': '22KiB',
  'estimated docs per chunk': 491
}
---
Shard shard1 at shard1/shard1:27018
{
  data: '23KiB',
  docs: 509,
  chunks: 1,
  'estimated data per chunk': '23KiB',
  'estimated docs per chunk': 509
}
---
Totals
{
  data: '45KiB',
  docs: 1000,
  chunks: 2,
  'Shard shard2': [
    '49.1 % data',
    '49.1 % docs in cluster',
    '46B avg obj size on shard'
  ],
  'Shard shard1': [
    '50.89 % data',
    '50.9 % docs in cluster',
    '46B avg obj size on shard'
  ]
}
```
### Если вы запускаете проект на предоставленной виртуальной машине

Узнать белый ip виртуальной машины

```shell
curl --silent http://ifconfig.me
```

Откройте в браузере http://<ip виртуальной машины>:8080

## Доступные эндпоинты

Список доступных эндпоинтов, swagger http://<ip виртуальной машины>:8080/docs