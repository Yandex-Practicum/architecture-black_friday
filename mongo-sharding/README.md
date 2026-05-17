# mongo-sharding

Шардирование в MongoDB. 2 шарда.

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
{"mongo_topology_type":"Sharded","mongo_replicaset_name":null,"mongo_db":"somedb","read_preference":"Primary()","mongo_nodes":[["mongos_router",27020]],"mongo_primary_host":null,"mongo_secondary_hosts":[],"mongo_is_primary":true,"mongo_is_mongos":true,"collections":{"helloDoc":{"documents_count":1000}},"shards":{"shard1":"shard1/shard1:27018","shard2":"shard2/shard2:27019"},"cache_enabled":false,"status":"OK"}
```
