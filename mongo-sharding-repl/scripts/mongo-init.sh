#!/bin/bash

set -e

echo "Ожидание запуска сервисов..."
sleep 10

###
# Инициализация Config Server Replica Set
###
echo "Инициализация Config Server..."
docker compose exec -T configSrv mongosh --port 27017 <<EOF
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
})
EOF

echo "Ожидание инициализации Config Server..."
sleep 5

###
# Инициализация Shard1 Replica Set
###
echo "Инициализация Shard1..."
docker compose exec -T shard1 mongosh --port 27018 <<EOF
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1:27018" }
  ]
})
EOF

echo "Ожидание инициализации Shard1..."
sleep 5

###
# Инициализация Shard2 Replica Set
###
echo "Инициализация Shard2..."
docker compose exec -T shard2 mongosh --port 27019 <<EOF
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2:27019" }
  ]
})
EOF

echo "Ожидание инициализации Shard2..."
sleep 5

###
# Добавление шардов в кластер через mongos
###
echo "Добавление шардов в кластер..."
docker compose exec -T mongos mongosh <<EOF
sh.addShard("shard1/shard1:27018")
sh.addShard("shard2/shard2:27019")
EOF

echo "Ожидание добавления шардов..."
sleep 5

###
# Включение шардинга для базы данных
###
echo "Включение шардинга для базы данных somedb..."
docker compose exec -T mongos mongosh <<EOF
sh.enableSharding("somedb")
EOF

echo "Ожидание включения шардинга..."
sleep 3

###
# Создание shard key для шардинга
# Используем hashed shard key для равномерного распределения данных между шардами
###
echo "Создание shard key для шардинга..."
docker compose exec -T mongos mongosh <<EOF
use somedb
sh.shardCollection("somedb.helloDoc", { age: "hashed" })
EOF

echo "Ожидание создания shard key..."
sleep 3

###
# Заполнение базы данных
###
echo "Заполнение базы данных..."
docker compose exec -T mongos mongosh somedb <<'EOF'
var docs = [];
for(var i = 0; i < 1000; i++) {
  docs.push({age: i, name: "ly" + i});
}
var result = db.helloDoc.insertMany(docs);
print("Вставлено документов: " + Object.keys(result.insertedIds).length);
EOF

echo "Инициализация завершена!"
echo "Проверка статуса шардинга:"
docker compose exec -T mongos mongosh --eval "sh.status()"
