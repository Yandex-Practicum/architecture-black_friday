#!/bin/bash

###
# Инициализация шардированного кластера
###

# 1. Инициализация конфигурационного сервера
docker compose exec -T configsvr mongosh --port 27018 <<EOF
rs.initiate({
  _id: "cfgrs",
  configsvr: true,
  members: [{ _id: 0, host: "configsvr:27018" }]
})
EOF

# 2. Инициализация шардов
docker compose exec -T shard1 mongosh --port 27019 <<EOF
rs.initiate({
  _id: "shard1rs",
  members: [{ _id: 0, host: "shard1:27019" }]
})
EOF

docker compose exec -T shard2 mongosh --port 27020 <<EOF
rs.initiate({
  _id: "shard2rs",
  members: [{ _id: 0, host: "shard2:27020" }]
})
EOF

# 3. Добавление шардов через mongos, создание базы данных и коллекции с тестовыми данными
docker compose exec -T mongos mongosh --port 27017 <<EOF
sh.addShard("shard1rs/shard1:27019")
sh.addShard("shard2rs/shard2:27020")
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})
db.helloDoc.countDocuments();
EOF
