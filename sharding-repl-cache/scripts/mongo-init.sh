#!/bin/bash

# 1. инициализация конфигурационного сервера
docker compose exec -T configSrv1 mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id: "config_server",
    configsvr: true,
    members: [
      { _id: 0, host: "configSrv1:27017" },
      { _id: 1, host: "configSrv2:27017" },
      { _id: 2, host: "configSrv3:27017" }
    ]
  }
)
EOF

# 2. инициализация шарда 1
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
  {
    _id: "shard1",
    members: [
      { _id: 0, host: "shard1-1:27018" },
      { _id: 1, host: "shard1-2:27018" },
      { _id: 2, host: "shard1-3:27018" }
    ]
  }
)
EOF

# 3. инициализация шарда 2
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.initiate(
  {
    _id: "shard2",
    members: [
      { _id: 0, host: "shard2-1:27019" },
      { _id: 1, host: "shard2-2:27019" },
      { _id: 2, host: "shard2-3:27019" }
    ]
  }
)
EOF

# ждем инициализацию конфигурационного сервера
sleep 20

# 4. добавление шардов в кластер и активация шардирования
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018")
sh.addShard("shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { name: "hashed" })
EOF

# 5. добавление 1000 документов в БД
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
for (var i = 0; i < 1000; i++) db.helloDoc.insertOne({ age: i, name: "ly" + i })
db.helloDoc.countDocuments()
EOF
