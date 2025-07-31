#!/bin/bash

echo "Настраиваем конфигурационный сервер"
docker compose exec -T configsvr mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [{_id: 0, host: "configsvr:27019"}]
})
EOF

echo "Настраиваем репликацию для shard1"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({_id: "shard1ReplSet", members: [{_id: 0, host: "shard1:27018"}]})
EOF

echo "Настраиваем репликацию для shard2"
docker compose exec -T shard2 mongosh --port 27020 --quiet <<EOF
rs.initiate({_id: "shard2ReplSet", members: [{_id: 0, host: "shard2:27020"}]})
EOF

echo "Ждем пока реплики запустятся..."
sleep 5

echo "Добавляем шард1 и шард2 в кластер"
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1ReplSet/shard1:27018")
sh.addShard("shard2ReplSet/shard2:27020")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })
EOF

echo "Добавляем данные в коллекцию (1500 записей)"
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
for (let i = 0; i < 1500; i++) {
  db.helloDoc.insert({ age: i, name: "ly" + i })
}
EOF

echo "Проверяем сколько документов в каждом шарде"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
print("shard1 количество:")
print(db.helloDoc.countDocuments())
EOF

docker compose exec -T shard2 mongosh --port 27020 --quiet <<EOF
use somedb
print("shard2 количество:")
print(db.helloDoc.countDocuments())
EOF
