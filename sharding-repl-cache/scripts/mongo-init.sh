#!/bin/bash

###
# Скрипт инициализации шардированного кластера MongoDB с репликацией
###

docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27017" }]
})
EOF

sleep 3

docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27118" },
    { _id: 2, host: "shard1-3:27218" }
  ]
})
EOF

sleep 3

docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2-1:27019" },
    { _id: 1, host: "shard2-2:27119" },
    { _id: 2, host: "shard2-3:27219" }
  ]
})
EOF

sleep 15

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018,shard1-2:27118,shard1-3:27218")
sh.addShard("shard2/shard2-1:27019,shard2-2:27119,shard2-3:27219")
EOF

sleep 3

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
EOF

sleep 2

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age: i, name: "ly" + i})
print("Всего документов в коллекции: " + db.helloDoc.countDocuments())
EOF
