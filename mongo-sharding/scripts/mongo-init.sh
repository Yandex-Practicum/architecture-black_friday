#!/bin/bash

set -e

echo "Инициализация кластера MongoDB..."

echo "1. Инициализация Config Server..."
docker compose exec -T mongo_config_srv mongosh --port 27019 --quiet <<EOF
rs.initiate({
    _id: "configrs",
    configsvr: true,
    members: [
        { _id: 0, host: "mongo_config_srv:27019" }
    ]
})
EOF

echo "Ожидание инициализации Config Server..."
sleep 10


echo "2. Инициализация Shard 1..."
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
    _id: "shard1rs",
    members: [
        { _id: 0, host: "shard1:27018" }
    ]
})
EOF

echo "3. Инициализация Shard 2..."
docker compose exec -T shard2 mongosh --port 27020 --quiet <<EOF
rs.initiate({
    _id: "shard2rs",
    members: [
        { _id: 0, host: "shard2:27020" }
    ]
})
EOF

echo "Ожидание инициализации шардов..."
sleep 15

echo "4. Добавление шардов в кластер..."
docker compose exec -T mongo_router mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1rs/shard1:27018")
print("Shard 1 добавлен успешно")

sh.addShard("shard2rs/shard2:27020")
print("Shard 2 добавлен успешно")
EOF

echo "5. Включение шардирования для базы somedb..."
docker compose exec -T mongo_router mongosh --port 27017 --quiet <<EOF
sh.enableSharding("somedb")
print("Шардирование включено для базы somedb")
EOF

echo "6. Создание индекса и шардированной коллекции helloDoc..."
docker compose exec -T mongo_router mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.createIndex({"name": 1})
print("Индекс на поле name создан")

sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
print("Коллекция helloDoc шардирована с hashed sharding по полю name")
EOF

echo "7. Заполнение базы данными..."
docker compose exec -T mongo_router mongosh <<EOF
use somedb
for(var i = 0; i < 2000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF

echo "8. Проверка количества документов на каждом шарде..."

echo "бщее количество документов через mongos:"
docker compose exec -T mongo_router mongosh --port 27017 --quiet <<EOF
use somedb
var totalCount = db.helloDoc.countDocuments()
print("Всего документов в коллекции helloDoc:", totalCount)
EOF

echo ""
echo "Количество документов на shard1:"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
var shard1Count = db.helloDoc.countDocuments()
print("Документов на shard1rs:", shard1Count)
EOF

echo ""
echo "Количество документов на shard2:"
docker compose exec -T shard2 mongosh --port 27020 --quiet <<EOF
use somedb
var shard2Count = db.helloDoc.countDocuments()
print("Документов на shard2rs:", shard2Count)
EOF

echo ""
echo "Дополнительная проверка балансировки (через 10 секунд):"
sleep 10
docker compose exec -T mongo_router mongosh --port 27017 --quiet <<EOF
use somedb
print("=== Финальное распределение данных ===")
db.helloDoc.getShardDistribution()

print("\n=== Статус балансировки ===")
sh.getBalancerState() ? print("Балансировщик: ВКЛЮЧЕН") : print("Балансировщик: ВЫКЛЮЧЕН")
sh.isBalancerRunning() ? print("Балансировка: АКТИВНА") : print("Балансировка: ЗАВЕРШЕНА")
EOF
