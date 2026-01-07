#!/bin/bash

set -e

echo "Подключение к серверу конфигурации и инициализация"
docker compose exec -T configSvr mongosh --port 27017 --quiet <<EOF
try {
    rs.initiate({
        _id: "configrs",
        configsvr: true,
        members: [
            { _id: 0, host: "configSvr:27017" }
        ]
    })
} catch(e) {
    print("Ошибка:", e.message)
}
EOF

sleep 10

echo "Инициализация шардов"
docker compose exec -T shard1_master mongosh --port 27018 --quiet <<EOF
try {
    rs.initiate({
        _id: "shard1rs",
        members: [
            { _id: 0, host: "shard1_master:27018", priority: 2 },
            { _id: 1, host: "shard1_slave1:27018", priority: 1 },
            { _id: 2, host: "shard1_slave2:27018", priority: 1 }
        ]
    })
} catch(e) {
    print("Ошибка:", e.message)
}
EOF

docker compose exec -T shard2_master mongosh --port 27019 --quiet <<EOF
try {
    rs.initiate({
        _id: "shard2rs",
        members: [
            { _id: 0, host: "shard2_master:27019", priority: 2 },
            { _id: 1, host: "shard2_slave1:27019", priority: 1 },
            { _id: 2, host: "shard2_slave2:27019", priority: 1 }
        ]
    })
} catch(e) {
    print("Ошибка:", e.message)
}
EOF

sleep 10

echo "Инициализация роутера и наполнение его тестовыми данными"
docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
try {
    sh.addShard("shard1rs/shard1_master:27018,shard1_slave1:27018,shard1_slave2:27018")
    print("Shard1 c репликами добавлен")
} catch(e) {
    print("Ошибка добавления Shard1:", e.message)
}
try {
    sh.addShard("shard2rs/shard2_master:27019,shard2_slave1:27019,shard2_slave2:27019")
    print("Shard2 c репликами добавлен")
} catch(e) {
    print("Ошибка добавления Shard2:", e.message)
}
try {
    sh.enableSharding("somedb")
} catch(e) {
    print("Ошибка шардирования:", e.message)
}
try {
    db.helloDoc.createIndex({"name": 1})
    sh.shardCollection("somedb.helloDoc", {"name": "hashed"})
} catch(e) {
    print("Ошибка:", e.message)
}
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF

echo "Проверка на шардах"

docker compose exec -T shard1_master mongosh --port 27018 --quiet <<EOF
use somedb
var shard1Count = db.helloDoc.countDocuments()
print("Документов на shard1:", shard1Count)
EOF

docker compose exec -T shard2_master mongosh --port 27019 --quiet <<EOF
use somedb
var shard2Count = db.helloDoc.countDocuments()
print("Документов на shard2:", shard2Count)
EOF

docker compose exec -T mongos mongosh --port 27020 --quiet <<EOF
use somedb
var totalCount = db.helloDoc.countDocuments()
print("Всего документов в базе:", totalCount)
EOF

echo "Статус shard1:"
docker compose exec -T shard1_master mongosh --port 27018 --quiet --eval "rs.status()"

echo "Статус shard2:"
docker compose exec -T shard2_master mongosh --port 27019 --quiet --eval "rs.status()"
