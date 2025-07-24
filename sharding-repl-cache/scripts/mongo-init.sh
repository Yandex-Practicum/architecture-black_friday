#!/bin/bash

# Инициализация реплика-сетов для шардов и конфиг-сервера
sleep 10

docker compose exec -T shard1-a mongosh --port 27018 --eval 'rs.initiate({_id: "rs-shard1", members: [{_id: 0, host: "shard1-a:27018"}, {_id: 1, host: "shard1-b:27018"}, {_id: 2, host: "shard1-c:27018"}]})'
docker compose exec -T shard2-a mongosh --port 27019 --eval 'rs.initiate({_id: "rs-shard2", members: [{_id: 0, host: "shard2-a:27019"}, {_id: 1, host: "shard2-b:27019"}, {_id: 2, host: "shard2-c:27019"}]})'
docker compose exec -T configsvr mongosh --port 27017 --eval 'rs.initiate({_id: "rs-config", configsvr: true, members: [{ _id: 0, host: "configsvr:27017" }]})'

# Добавление шардов в кластер через mongos
sleep 15
docker compose exec -T mongos mongosh --port 27017 --eval '
  sh.addShard("rs-shard1/shard1-a:27018");
  sh.addShard("rs-shard2/shard2-a:27019");
  sh.status();
'

# Включение шардирования для базы и коллекции

docker compose exec -T mongos mongosh --port 27017 <<EOF
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF
