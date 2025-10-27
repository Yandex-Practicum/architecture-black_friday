# pymongo-api

## Как запустить

### Запускаем mongodb и приложение

```shell
   docker compose -f compose.yaml up -d
```

### Инициализация config server
```shell

docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
)
EOF
```

### Инициализация шард
```shell

docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1:27018" },
        { _id : 1, host : "shard1-replica1:27021" },
        { _id : 2, host : "shard1-replica2:27022" }
      ]
    }
)
EOF
```
```shell

docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "shard2:27019" },
        { _id : 1, host : "shard2-replica1:27023" },
        { _id : 2, host : "shard2-replica2:27024" }
      ]
    }
)
EOF
```

### Инициализируем роутер 
```shell

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1:27018,shard1-replica1:27021,shard1-replica2:27022")
sh.addShard("shard2/shard2:27019,shard2-replica1:27023,shard2-replica2:27024")
sh.status()

sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
EOF
```

### наполняем данными
```shell

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
db.helloDoc.countDocuments()
EOF
```

### Проверка шарды-1
```shell

docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb;
db.helloDoc.countDocuments();
EOF
```

### Проверка реплики-1 шарды-1
```shell

docker compose exec -T shard1-replica1 mongosh --port 27021   --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

### Проверка шарды-2
```shell

docker compose exec -T shard2 mongosh --port 27019   --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

### Проверка реплики-2 шарды-2
```shell

docker compose exec -T shard2-replica2 mongosh --port 27024   --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

### Создаем Redis cluster
```shell

docker compose exec -T redis_1 bash -c "echo yes | redis-cli --cluster create \
  173.17.0.2:6379 \
  173.17.0.3:6379 \
  173.17.0.4:6379 \
  173.17.0.5:6379 \
  173.17.0.6:6379 \
  173.17.0.7:6379 \
  --cluster-replicas 1"
```

### Останавливаем mongodb и приложение
```shell

docker-compose down -v
```