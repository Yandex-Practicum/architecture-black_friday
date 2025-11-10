#!/bin/bash

set -e

echo "Инициализация кластера MongoDB с репликацией шардов..."
echo ""

echo "1. Инициализация Config Server..."
docker compose exec -T mongo_config_srv mongosh --port 27019 --quiet <<EOF
rs.initiate({
    _id: "configrs",
    configsvr: true,
    members: [
        { _id: 0, host: "mongo_config_srv:27019" }
    ]
})
print("Config Server инициализирован")
EOF

echo "Ожидание готовности Config Server..."
sleep 10

echo "2. Инициализация Shard 1 Replica Set..."
docker compose exec -T shard1_primary mongosh --port 27018 --quiet <<EOF
rs.initiate({
    _id: "shard1rs",
    members: [
        { _id: 0, host: "shard1_primary:27018", priority: 10 },
        { _id: 1, host: "shard1_secondary1:27018", priority: 5 },
        { _id: 2, host: "shard1_secondary2:27018", priority: 1 }
    ]
})
print("Shard 1 Replica Set инициализирован")
EOF

echo "3. Инициализация Shard 2 Replica Set..."
docker compose exec -T shard2_primary mongosh --port 27020 --quiet <<EOF
rs.initiate({
    _id: "shard2rs",
    members: [
        { _id: 0, host: "shard2_primary:27020", priority: 10 },
        { _id: 1, host: "shard2_secondary1:27020", priority: 5 },
        { _id: 2, host: "shard2_secondary2:27020", priority: 1 }
    ]
})
print("Shard 2 Replica Set инициализирован")
EOF

echo "Ожидание готовности всех Replica Sets..."
sleep 20

echo "4. Добавление шардов в кластер..."
docker compose exec -T mongo_router mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1rs/shard1_primary:27018,shard1_secondary1:27018,shard1_secondary2:27018")
print("Shard 1 Replica Set добавлен в кластер")

sh.addShard("shard2rs/shard2_primary:27020,shard2_secondary1:27020,shard2_secondary2:27020")
print("Shard 2 Replica Set добавлен в кластер")
EOF

echo "5. Настройка шардирования базы данных..."
docker compose exec -T mongo_router mongosh --port 27017 --quiet <<EOF
sh.enableSharding("somedb")
print("Шардирование включено для базы somedb")
EOF

echo "6. Создание шардированной коллекции..."
docker compose exec -T mongo_router mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.createIndex({"name": 1})
print("Индекс создан")

sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
print("Коллекция helloDoc шардирована с hashed sharding")
EOF

echo "7. Заполнение базы данными..."
docker compose exec -T mongo_router mongosh --port 27017 --quiet <<EOF
use somedb
print("Добавление 5000 документов...")
for(var i = 0; i < 5000; i++) {
    db.helloDoc.insertOne({
        age: i % 100,
        name: "user" + String(i).padStart(5, '0'),
        timestamp: new Date(),
        data: "sample_data_" + i
    })
    if (i % 1000 === 0 && i > 0) {
        print("Добавлено", i, "документов")
    }
}
print("Добавлено 5000 документов")
EOF

echo "8. Проверка состояния кластера..."

echo "Общее количество документов:"
docker compose exec -T mongo_router mongosh --port 27017 --quiet <<EOF
use somedb
var totalCount = db.helloDoc.countDocuments()
print("Всего документов:", totalCount)
EOF

echo "Распределение данных по шардам:"
docker compose exec -T mongo_router mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.getShardDistribution()
EOF

echo "Статус replica sets:"
echo "Shard 1 Replica Set:"
docker compose exec -T shard1_primary mongosh --port 27018 --quiet <<EOF
var status = rs.status()
status.members.forEach(function(member) {
    print("     ", member.name, "-", member.stateStr)
})
EOF

echo "Shard 2 Replica Set:"
docker compose exec -T shard2_primary mongosh --port 27020 --quiet <<EOF
var status = rs.status()
status.members.forEach(function(member) {
    print("     ", member.name, "-", member.stateStr)
})
EOF

