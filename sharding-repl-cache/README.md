Запускаем mongodb и приложение

```shell
cd mongo-sharding
docker compose up -d
```

Инициализируйте конфигурационный сервер

```shell
docker compose exec -T configSrv mongosh --port 27017 <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
exit();
EOF
```

Инициализируем 1-ый шард с репликами

```shell
docker compose exec -T shard1_1 mongosh --port 27021 --quiet <<EOF
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1_1:27021" },
        { _id : 1, host : "shard1_2:27022" },
        { _id : 2, host : "shard1_3:27023" },
      ]
    }
);
exit();
EOF
```

Инициализируем 2-ой шард  с репликами

```shell
docker compose exec -T shard2_1 mongosh --port 27024 --quiet <<EOF
rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "shard2_1:27024" },
        { _id : 1, host : "shard2_2:27025" },
        { _id : 2, host : "shard2_3:27026" },
      ]
    }
);
exit();
EOF
```

Инициализируем роутер и выполняем цикл, который создает тысячу записей

```shell
docker compose exec -T mongos_router mongosh --port 27020 <<EOF
sh.addShard("shard1/shard1_1:27021");
sh.addShard("shard2/shard2_1:27024");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" });

use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF
```

Делаем проверку результатов на 1-ом шарде

```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Делаем проверку результатов на 2-ом шарде

```shell
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```