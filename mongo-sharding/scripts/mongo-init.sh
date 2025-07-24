#!/bin/bash

# Инициализация реплика-сетов для шардов

docker compose exec -T shard1 mongosh --port 27018 --eval 'rs.initiate({_id: "rs-shard1", members: [{ _id: 0, host: "shard1:27018" }]})'
docker compose exec -T shard2 mongosh --port 27019 --eval 'rs.initiate({_id: "rs-shard2", members: [{ _id: 0, host: "shard2:27019" }]})'
docker compose exec -T configsvr mongosh --port 27017 --eval 'rs.initiate({_id: "rs-config", configsvr: true, members: [{ _id: 0, host: "configsvr:27017" }]})'

# Добавление шардов в кластер через mongos
sleep 5
docker compose exec -T mongos mongosh --port 27017 --eval '
  sh.addShard("rs-shard1/shard1:27018");
  sh.addShard("rs-shard2/shard2:27019");
  sh.status();
'

# Включение шардирования для базы и коллекции

docker compose exec -T mongos mongosh --port 27017 <<EOF
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF
