#!/bin/bash

set -e

echo "Инициализация шардированного кластера MongoDB..."

echo "1. Инициализация Config Server..."
docker compose exec -T configSvr mongosh --port 27018 --quiet <<EOF
try {
    rs.initiate({
        _id: "configrs",
        configsvr: true,
        members: [
            { _id: 0, host: "configsvr:27018" }
        ]
    })
} catch(e) {
    print("Config Server уже инициализирован или произошла ошибка:", e.message)
}
EOF

echo "Ожидание инициализации Config Server..."
sleep 10

echo "2. Инициализация Shard 1..."
docker compose exec -T shard1 mongosh --port 27011 --quiet <<EOF
try {
    rs.initiate({
        _id: "shard1rs",
        members: [
            { _id: 0, host: "shard1:27011" }
        ]
    })
} catch(e) {
    print("Shard 1 уже инициализирован или произошла ошибка:", e.message)
}
EOF

echo "3. Инициализация Shard 2..."
docker compose exec -T shard2 mongosh --port 27012 --quiet <<EOF
try {
    rs.initiate({
        _id: "shard2rs",
        members: [
            { _id: 0, host: "shard2:27012" }
        ]
    })
} catch(e) {
    print("Shard 2 уже инициализирован или произошла ошибка:", e.message)
}
EOF

echo "Ожидание инициализации шардов..."
sleep 15

echo "4. Добавление шардов в кластер..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
try {
    sh.addShard("shard1rs/shard1:27011")
    print("Shard 1 добавлен успешно")
} catch(e) {
    print("Ошибка при добавлении Shard 1:", e.message)
}

try {
    sh.addShard("shard2rs/shard2:27012")
    print("Shard 2 добавлен успешно")
} catch(e) {
    print("Ошибка при добавлении Shard 2:", e.message)
}
EOF

echo "5. Включение шардирования для базы 'somedb'..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
try {
    sh.enableSharding("somedb")
    print("Шардирование включено для базы 'somedb'")
} catch(e) {
    print("Ошибка при включении шардирования:", e.message)
}
EOF

echo "6. Создание индекса и шардированной коллекции 'helloDoc'..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
try {
    db.helloDoc.createIndex({"name": 1})
    print("Индекс на поле 'name' создан")

    sh.shardCollection("somedb.helloDoc", { "name": "hashed" })
    print("Коллекция 'helloDoc' шардирована по полю 'name' (hashed)")
} catch(e) {
    print("Ошибка при создании индекса или шардировании:", e.message)
}
EOF

echo "7. Заполнение базы тестовыми данными..."
docker compose exec -T mongos mongosh <<EOF
use somedb
for (var i = 0; i < 1500; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF

echo "8. Проверка количества документов на каждом шарде..."

echo "Общее количество документов через mongos:"
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
var totalCount = db.helloDoc.countDocuments()
print("Всего документов в коллекции 'helloDoc':", totalCount)
EOF

echo "Количество документов на Shard 1:"
docker compose exec -T shard1 mongosh --port 27011 --quiet <<EOF
use somedb
var shard1Count = db.helloDoc.countDocuments()
print("Документов на shard1rs:", shard1Count)
EOF

echo "Количество документов на Shard 2:"
docker compose exec -T shard2 mongosh --port 27012 --quiet <<EOF
use somedb
var shard2Count = db.helloDoc.countDocuments()
print("Документов на shard2rs:", shard2Count)
EOF

echo "Дополнительная проверка балансировки (через 10 секунд)..."
sleep 10
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
print("=== Финальное распределение данных ===")
db.helloDoc.getShardDistribution()

print("\n=== Статус балансировки ===")
sh.getBalancerState() ? print("Балансировщик: включен") : print("Балансировщик: выключен")
sh.isBalancerRunning() ? print("Балансировка: выполняется") : print("Балансировка: завершена")
EOF
