# mongo-sharding

Шардирование в MongoDB. 2 шарда. 3 реплики в каждом шарде

## Как запустить

Запускаем mongodb и приложение

```shell
docker compose up -d
```
Убедиться, что все контейнеры запущены:

```shell
docker compose ps
```

Заполняем mongodb данными

```shell
./scripts/mongo-init.sh
```

Проверить, что данные загружены и распределены по шардам:

```shell
./scripts/check_mongo.sh
```

## Как проверить

Откройте в браузере http://localhost:8080

Убедиться, что получен результат вида:

```quote
{"mongo_topology_type":"Sharded","mongo_replicaset_name":null,"mongo_db":"somedb","read_preference":"Primary()","mongo_nodes":[["mongos_router",27020]],"mongo_primary_host":null,"mongo_secondary_hosts":[],"mongo_is_primary":true,"mongo_is_mongos":true,"collections":{"helloDoc":{"documents_count":1000}},"shards":{"shard1":"shard1/shard1-1:27018,shard1-2:27028,shard1-3:27038","shard2":"shard2/shard2-1:27019,shard2-2:27029,shard2-3:27039"},"cache_enabled":true,"status":"OK"}

```

Выполнить первый запрос
```shell
time curl http://localhost:8080/helloDoc/users
```

Выполнить второй запрос менее чем 60 секунд после первого
```shell
time curl http://localhost:8080/helloDoc/users
```

Убедиться, что чторой запрос выполняется менее 100 миллисекунд.

