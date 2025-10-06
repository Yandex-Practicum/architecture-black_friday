#!/bin/bash

echo "=== Инициализация Config Server ==="
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27017" }]
})
EOF

echo "Ожидание инициализации Config Server..."
sleep 5

echo "=== Инициализация Shard 1 ==="
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1ReplSet",
  members: [{ _id: 0, host: "shard1:27018" }]
})
EOF

echo "Ожидание инициализации Shard 1..."
sleep 5

echo "=== Инициализация Shard 2 ==="
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2ReplSet",
  members: [{ _id: 0, host: "shard2:27019" }]
})
EOF

echo "Ожидание инициализации Shard 2..."
sleep 5

echo "=== Добавление шардов в кластер ==="
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1ReplSet/shard1:27018")
sh.addShard("shard2ReplSet/shard2:27019")
sh.status()
EOF

echo "=== Включение шардирования для базы данных ==="
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.enableSharding("somedb")
EOF

echo "=== Создание и шардирование коллекции ==="
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
db.createCollection("helloDoc")
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })
EOF

echo "=== Наполнение базы данных ==="
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({age: i, name: "ly" + i})
}
db.helloDoc.countDocuments()
EOF

echo "=== Проверка распределения данных по шардам ==="
echo "Shard 1:"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Shard 2:"
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "=== Инициализация завершена ==="
